package kvm

import (
	"fmt"
	"os"
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

type Machine struct {
	kvm  uintptr
	vm   *VM
	runs []*RunData
}

func NewMachine(kvmPath string, ncpus int, memSize int) (*Machine, error) {
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
		kvm: kvmfd,
		vm:  vm,
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
