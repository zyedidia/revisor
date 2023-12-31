package kvm

import (
	"fmt"
	"os"
	"unsafe"

	"github.com/tysonmote/gommap"
)

const (
	physSysBase  = 0x0000_4000
	physRamBase  = 0x4000_0000
	physKernBase = 0x4000_8000
)

type vm struct {
	fd    uintptr
	mem   gommap.MMap
	sys   gommap.MMap
	vcpus []vcpu
}

func NewVM(kvmfd uintptr, memSize int64) (*vm, error) {
	v, err := getAPIVersion(kvmfd)
	if err != nil {
		return nil, err
	}
	if v != 12 {
		return nil, fmt.Errorf("KVM_GET_API_VERSION: got %d, expected 12", v)
	}
	vmfd, err := createVM(kvmfd)
	if err != nil {
		return nil, fmt.Errorf("KVM_CREATE_VM: %w", err)
	}
	nofd := -1
	mem, err := gommap.MapAt(0, uintptr(nofd), 0, memSize, gommap.PROT_READ|gommap.PROT_WRITE, gommap.MAP_SHARED|gommap.MAP_ANONYMOUS)
	if err != nil {
		return nil, fmt.Errorf("mmap: %w", err)
	}
	sys, err := gommap.MapAt(0, uintptr(nofd), 0, int64(os.Getpagesize()), gommap.PROT_NONE, gommap.MAP_SHARED|gommap.MAP_ANONYMOUS)
	if err != nil {
		return nil, fmt.Errorf("mmap: %w", err)
	}

	return &vm{
		fd:  vmfd,
		mem: mem,
		sys: sys,
	}, nil
}

func (vm *vm) initMemory() error {
	if err := vm.SetUserspaceMemoryRegion(&UserspaceMemoryRegion{
		Slot:          0,
		GuestPhysAddr: physRamBase,
		MemorySize:    uint64(len(vm.mem)),
		UserspaceAddr: uint64(uintptr(unsafe.Pointer(&vm.mem[0]))),
	}); err != nil {
		return fmt.Errorf("KVM_SET_USERSPACE_MEMORY_REGION: %w", err)
	}
	if err := vm.SetUserspaceMemoryRegion(&UserspaceMemoryRegion{
		Slot:          1,
		GuestPhysAddr: physSysBase,
		MemorySize:    uint64(len(vm.sys)),
		UserspaceAddr: uint64(uintptr(unsafe.Pointer(&vm.sys[0]))),
		Flags:         kvmMemReadonly,
	}); err != nil {
		return fmt.Errorf("KVM_SET_USERSPACE_MEMORY_REGION: %w", err)
	}
	return nil
}

func (vm *vm) addVCPU() error {
	fd, err := Ioctl(vm.fd, IIO(kvmCreateVCPU), uintptr(len(vm.vcpus)))
	if err != nil {
		return err
	}
	vm.vcpus = append(vm.vcpus, vcpu{
		fd: fd,
	})
	return nil
}
