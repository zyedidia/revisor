package kvm

import (
	"fmt"
	"unsafe"

	"github.com/tysonmote/gommap"
)

type vm struct {
	fd    uintptr
	mem   gommap.MMap
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
		return nil, err
	}
	nofd := -1
	mem, err := gommap.MapAt(0, uintptr(nofd), 0, memSize, gommap.PROT_READ|gommap.PROT_WRITE, gommap.MAP_SHARED|gommap.MAP_ANONYMOUS)
	if err != nil {
		return nil, err
	}

	return &vm{
		fd:  vmfd,
		mem: mem,
	}, nil
}

func (vm *vm) InitMemory() error {
	return vm.SetUserspaceMemoryRegion(&UserspaceMemoryRegion{
		Slot:          0,
		GuestPhysAddr: 0,
		MemorySize:    uint64(len(vm.mem)),
		UserspaceAddr: uint64(uintptr(unsafe.Pointer(&vm.mem[0]))),
	})
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
