package kvm

import (
	"debug/elf"
	"errors"
	"fmt"
	"io"
	"os"
	"runtime"
	"sync"
	"syscall"
	"unsafe"
)

const (
	bootParamAddr = 0x10000
	cmdlineAddr   = 0x20000

	initrdAddr  = 0xf000000
	highMemBase = 0x100000

	pageTableBase = 0x30_000

	MinMemSize = 1 << 25
)

type HyperHandlerFn func(regs *Regs, mem []byte)

type Machine struct {
	kvm     uintptr
	vm      *VM
	runs    []*RunData
	handler HyperHandlerFn
}

func NewMachine(kvmPath string, ncpus int, memSize int, hyperhandler HyperHandlerFn) (*Machine, error) {
	if memSize < MinMemSize {
		return nil, fmt.Errorf("memory size %d: too small", memSize)
	}
	devkvm, err := os.OpenFile(kvmPath, os.O_RDWR, 0o644)
	if err != nil {
		return nil, err
	}
	kvmfd := devkvm.Fd()
	vm, err := NewVM(kvmfd, int64(memSize))
	if err != nil {
		return nil, err
	}

	mmapSize, err := getVCPUMMmapSize(kvmfd)
	if err != nil {
		return nil, err
	}

	m := &Machine{
		kvm:     kvmfd,
		vm:      vm,
		runs:    make([]*RunData, ncpus),
		handler: hyperhandler,
	}

	for cpu := 0; cpu < ncpus; cpu++ {
		err := vm.addVCPU()
		if err != nil {
			return nil, err
		}

		// init kvm_run structure
		r, err := syscall.Mmap(int(vm.vcpus[cpu].fd), 0, int(mmapSize), syscall.PROT_READ|syscall.PROT_WRITE, syscall.MAP_SHARED)
		if err != nil {
			return nil, err
		}
		m.runs[cpu] = (*RunData)(unsafe.Pointer(&r[0]))
	}

	// initialize cpuids
	for i := range m.runs {
		if err := m.initCPUID(i); err != nil {
			return nil, err
		}
	}

	// initialize memory
	err = vm.InitMemory()
	if err != nil {
		return nil, err
	}

	// TODO: poison memory

	return m, nil
}

func getVCPUMMmapSize(kvmfd uintptr) (uintptr, error) {
	return Ioctl(kvmfd, IIO(kvmGetVCPUMMapSize), uintptr(0))
}

func (m *Machine) initCPUID(cpu int) error {
	cpuid := CPUID{
		Nent:    100,
		Entries: make([]CPUIDEntry2, 100),
	}

	if err := m.GetSupportedCPUID(&cpuid); err != nil {
		return err
	}

	// https://www.kernel.org/doc/html/v5.7/virt/kvm/cpuid.html
	for i := 0; i < int(cpuid.Nent); i++ {
		if cpuid.Entries[i].Function == CPUIDFuncPerMon {
			cpuid.Entries[i].Eax = 0 // disable
		} else if cpuid.Entries[i].Function == CPUIDSignature {
			cpuid.Entries[i].Eax = CPUIDFeatures
			cpuid.Entries[i].Ebx = 0x4b4d564b // KVMK
			cpuid.Entries[i].Ecx = 0x564b4d56 // VMKV
			cpuid.Entries[i].Edx = 0x4d       // M
		}
	}

	if err := m.vm.vcpus[cpu].SetCPUID2(&cpuid); err != nil {
		return err
	}

	return nil
}

func (m *Machine) Translate(cpu int, vaddr uint64) (Translation, error) {
	tr := &Translation{
		LinearAddress: vaddr,
	}
	err := m.vm.vcpus[cpu].Translate(tr)
	return *tr, err
}

func (m *Machine) SetupRegs(rip, bp uint64, amd64 bool) error {
	for _, cpu := range m.vm.vcpus {
		if err := cpu.initRegs(rip, bp); err != nil {
			return err
		}
		if err := cpu.initSregs(m.vm.mem, amd64); err != nil {
			return err
		}
	}
	return nil
}

// RunInfiniteLoop runs the guest cpu until there is an error.
// If the error is ErrExitDebug, this function can be called again.
func (m *Machine) RunInfiniteLoop(cpu int) error {
	// https://www.kernel.org/doc/Documentation/virtual/kvm/api.txt
	// - vcpu ioctls: These query and set attributes that control the operation
	//   of a single virtual cpu.
	//
	//   vcpu ioctls should be issued from the same thread that was used to create
	//   the vcpu, except for asynchronous vcpu ioctl that are marked as such in
	//   the documentation.  Otherwise, the first ioctl after switching threads
	//   could see a performance impact.
	//
	// - device ioctls: These query and set attributes that control the operation
	//   of a single device.
	//
	//   device ioctls must be issued from the same process (address space) that
	//   was used to create the VM.
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()

	for {
		isContinue, err := m.RunOnce(cpu)
		if isContinue {
			if err != nil {
				fmt.Fprintf(os.Stderr, "%v\n", err)
			}

			continue
		}

		return err
	}
}

var (
	// ErrUnexpectedExitReason is any error that we do not understand.
	ErrUnexpectedExitReason = errors.New("unexpected kvm exit reason")

	// ErrDebug is a debug exit, caused by single step or breakpoint.
	ErrDebug = errors.New("debug exit")
)

// RunOnce runs the guest vCPU until it exits.
func (m *Machine) RunOnce(cpu int) (bool, error) {
	if cpu >= len(m.vm.vcpus) {
		return false, fmt.Errorf("CPU %d out of range", cpu)
	}

	vcpu := m.vm.vcpus[cpu]

	_ = vcpu.Run()
	exit := ExitType(m.runs[cpu].ExitReason)

	switch exit {
	case EXITHLT:
		return false, nil
	case EXITIO:
		regs, err := vcpu.GetRegs()
		if err != nil {
			return false, err
		}
		m.handler(regs, m.vm.mem)
		if err := vcpu.SetRegs(regs); err != nil {
			return false, err
		}
		return true, nil
	case EXITUNKNOWN:
		return true, nil
	case EXITINTR:
		// When a signal is sent to the thread hosting the VM it will result in EINTR
		// refs https://gist.github.com/mcastelino/df7e65ade874f6890f618dc51778d83a
		return true, nil
	case EXITDEBUG:
		return false, errors.New("error: debug trap")

	case EXITDCR,
		EXITEXCEPTION,
		EXITFAILENTRY,
		EXITHYPERCALL,
		EXITINTERNALERROR,
		EXITIRQWINDOWOPEN,
		EXITMMIO,
		EXITNMI,
		EXITS390RESET,
		EXITS390SIEIC,
		EXITSETTPR,
		EXITSHUTDOWN,
		EXITTPRACCESS:
		return false, fmt.Errorf("%w: %s", ErrUnexpectedExitReason, exit.String())
	default:
		return false, fmt.Errorf("%w: %v", ErrUnexpectedExitReason, ExitType(m.runs[cpu].ExitReason).String())
	}
}

func (m *Machine) LoadKernel(kernel io.ReaderAt, params string) error {
	copy(m.vm.mem[cmdlineAddr:], params)
	m.vm.mem[cmdlineAddr+len(params)] = 0 // null terminated

	e, err := elf.NewFile(kernel)
	if err != nil {
		return err
	}

	amd64 := e.Class == elf.ELFCLASS64
	entry := e.Entry
	kernSize := 0

	for i, p := range e.Progs {
		if p.Type != elf.PT_LOAD {
			continue
		}

		n, err := p.ReadAt(m.vm.mem[p.Paddr:], 0)
		if !errors.Is(err, io.EOF) || uint64(n) != p.Filesz {
			return fmt.Errorf("reading ELF prog %d@%#x: %d/%d bytes, err %w", i, p.Paddr, n, p.Filesz, err)
		}
		kernSize += n
	}

	if kernSize == 0 {
		return fmt.Errorf("kernel is empty")
	}

	if err := m.SetupRegs(entry, cmdlineAddr, amd64); err != nil {
		return err
	}

	return nil
}

func (m *Machine) StartVCPU(cpu int, wg *sync.WaitGroup) {
	go func(cpu int) {
		err := m.RunInfiniteLoop(cpu)
		wg.Done()
		fmt.Printf("CPU %d exited (err=%v)\n\r", cpu, err)
	}(cpu)
}

func (m *Machine) NCPU() int {
	return len(m.vm.vcpus)
}

func getAPIVersion(kvmfd uintptr) (uintptr, error) {
	return Ioctl(kvmfd, IIO(kvmGetAPIVersion), uintptr(0))
}

func createVM(kvmfd uintptr) (uintptr, error) {
	return Ioctl(kvmfd, IIO(kvmCreateVM), uintptr(0))
}
