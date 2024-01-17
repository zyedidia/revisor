package kvm

import (
	"bytes"
	"debug/elf"
	"errors"
	"fmt"
	"io"
	"os"
	"reflect"
	"runtime"
	"sync"
	"syscall"
	"unsafe"
)

type HypercallHandler interface {
	Hypercall(machine *Machine, cpu int, number, a0, a1, a2, a3, a4, a5 uint64) (r0 uint64, err error)
}

type Machine struct {
	kvmfd   uintptr
	irqfd   uintptr
	vm      *vm
	runs    []*RunData
	handler HypercallHandler
}

func NewMachine(kvmPath string, ncpus int, memSize int64, handler HypercallHandler) (*Machine, error) {
	devkvm, err := os.OpenFile(kvmPath, os.O_RDWR, 0o644)
	if err != nil {
		return nil, err
	}
	kvmfd := devkvm.Fd()
	vm, err := NewVM(kvmfd, int64(memSize))
	if err != nil {
		return nil, err
	}

	if err := vm.init(); err != nil {
		return nil, err
	}

	mmapSize, err := getVCPUMMmapSize(kvmfd)
	if err != nil {
		return nil, err
	}

	m := &Machine{
		kvmfd:   kvmfd,
		vm:      vm,
		runs:    make([]*RunData, ncpus),
		handler: handler,
	}

	err = m.createIrqController()
	if err != nil {
		return nil, err
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

	err = m.init()
	if err != nil {
		return nil, err
	}

	// initialize memory
	err = vm.initMemory()
	if err != nil {
		return nil, err
	}

	err = m.finalizeIrqController()
	if err != nil {
		return nil, err
	}

	// TODO: poison memory

	return m, nil
}

func (m *Machine) LoadKernel(kernel io.ReaderAt, args []string) error {
	e, err := elf.NewFile(kernel)
	if err != nil {
		return err
	}

	entry := e.Entry
	kernSize := 0

	for i, p := range e.Progs {
		if p.Type != elf.PT_LOAD {
			continue
		}

		n, err := p.ReadAt(m.vm.mem[ka2pa(p.Vaddr)-physRamBase:], 0)
		if !errors.Is(err, io.EOF) || uint64(n) != p.Filesz {
			return fmt.Errorf("reading ELF prog %d@%#x: %d/%d bytes, err %w", i, p.Vaddr, n, p.Filesz, err)
		}
		start := ka2pa(p.Vaddr) - physRamBase
		for i := start + p.Filesz; i < start+p.Memsz; i++ {
			m.vm.mem[i] = 0
		}
		kernSize += n
	}

	argv := argv{
		args: args,
	}
	argvAddr, err := argv.WriteAt(m.vm.mem, 0)
	if err != nil {
		return err
	}

	if kernSize == 0 {
		return fmt.Errorf("kernel is empty")
	}

	if err := m.SetupRegs(entry, uint64(len(args)), argvAddr); err != nil {
		return err
	}

	return nil
}

func (m *Machine) StartVCPU(cpu int, trace bool, wg *sync.WaitGroup) {
	m.SingleStep(trace)

	go func(cpu int) {
		var err error
		for tc := 0; ; tc++ {
			err = m.RunInfiniteLoop(cpu, trace)
			if !trace {
				break
			}
			if !errors.Is(err, ErrDebug) {
				break
			}
			pc, s, err := m.Inst(cpu)
			if err != nil {
				fmt.Printf("disassembling after debug exit:%v\n", err)
			} else {
				fmt.Printf("%#x:%s\n", pc, s)
			}
			m.SingleStep(trace)
		}

		fmt.Fprintf(os.Stderr, "CPU %d exited (err=%v)\n", cpu, err)
		wg.Done()
	}(cpu)
}

// RunInfiniteLoop runs the guest cpu until there is an error.
// If the error is ErrExitDebug, this function can be called again.
func (m *Machine) RunInfiniteLoop(cpu int, trace bool) error {
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

			m.SingleStep(trace)

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

	err := vcpu.Run()
	if err != nil {
		return false, err
	}
	exit := ExitType(m.runs[cpu].ExitReason)

	switch exit {
	case ExitHlt:
		return false, nil
	case ExitMMIO, ExitIO:
		err := m.hypercall(cpu)
		if err != nil {
			return false, err
		}
		return true, nil
	case ExitUnknown:
		return true, nil
	case ExitIntr:
		// When a signal is sent to the thread hosting the VM it will result in EINTR
		// refs https://gist.github.com/mcastelino/df7e65ade874f6890f618dc51778d83a
		return true, nil
	case ExitDebug:
		return false, ErrDebug
	default:
		return false, fmt.Errorf("%w: %v", ErrUnexpectedExitReason, ExitType(m.runs[cpu].ExitReason).String())
	}
}

// SingleStep enables single stepping the guest.
func (m *Machine) SingleStep(onoff bool) error {
	for _, cpu := range m.vm.vcpus {
		if err := cpu.SingleStep(onoff); err != nil {
			return fmt.Errorf("single step %d:%w", cpu, err)
		}
	}

	return nil
}

// ReadAt implements io.ReadAt for the kvm guest pvh.
func (m *Machine) ReadAt(b []byte, off int64) (int, error) {
	mem := bytes.NewReader(m.vm.mem)

	return mem.ReadAt(b, off-physRamBase)
}

// ReadBytes reads bytes from the CPUs virtual address space.
func (m *Machine) ReadBytes(cpu int, b []byte, vaddr uint64) (int, error) {
	pa := m.VtoP(cpu, vaddr)
	return m.ReadAt(b, int64(pa))
}

func (m *Machine) SliceEnd(start uint64) []byte {
	return m.vm.mem[start-physRamBase:]
}

func (m *Machine) Slice(start, end uint64) []byte {
	return m.vm.mem[start-physRamBase : end-physRamBase]
}

func (m *Machine) NCPU() int {
	return len(m.vm.vcpus)
}

func showone(indent string, in interface{}) string {
	var ret string

	s := reflect.ValueOf(in).Elem()
	typeOfT := s.Type()

	for i := 0; i < s.NumField(); i++ {
		f := s.Field(i)
		if f.Kind() == reflect.String {
			ret += fmt.Sprintf(indent+"%s %s = %s\n", typeOfT.Field(i).Name, f.Type(), f.Interface())
		} else {
			ret += fmt.Sprintf(indent+"%s %s = %#x\n", typeOfT.Field(i).Name, f.Type(), f.Interface())
		}
	}

	return ret
}

func show(indent string, l ...interface{}) string {
	var ret string
	for _, i := range l {
		ret += showone(indent, i)
	}

	return ret
}

func (m *Machine) GetPc(cpu int) uint64 {
	return m.vm.vcpus[cpu].GetPc()
}
