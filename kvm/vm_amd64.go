package kvm

// SetTSSAddr sets the Task Segment Selector for a vm.
func (vm *vm) SetTSSAddr(addr uint32) error {
	_, err := Ioctl(vm.fd, IIO(kvmSetTSSAddr), uintptr(addr))

	return err
}
