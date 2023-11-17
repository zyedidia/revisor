package kvm

import "unsafe"

type UserspaceMemoryRegion struct {
	Slot          uint32
	Flags         uint32
	GuestPhysAddr uint64
	MemorySize    uint64
	UserspaceAddr uint64
}

func (vm *VM) SetUserspaceMemoryRegion(region *UserspaceMemoryRegion) error {
	_, err := Ioctl(vm.fd, IIOW(kvmSetUserMemoryRegion, unsafe.Sizeof(UserspaceMemoryRegion{})),
		uintptr(unsafe.Pointer(region)))

	return err

}
