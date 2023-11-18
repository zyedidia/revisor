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

// SetTSSAddr sets the Task Segment Selector for a vm.
func (vm *VM) SetTSSAddr(addr uint32) error {
	_, err := Ioctl(vm.fd, IIO(kvmSetTSSAddr), uintptr(addr))

	return err
}

// SetIdentityMapAddr sets the address of a 4k-sized-page for a vm.
func (vm *VM) SetIdentityMapAddr(addr uint32) error {
	_, err := Ioctl(vm.fd, IIOW(kvmSetIdentityMapAddr, 8), uintptr(unsafe.Pointer(&addr)))

	return err
}
