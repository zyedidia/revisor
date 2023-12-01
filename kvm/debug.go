package kvm

import "unsafe"

// debugControl controls guest debug.
type debugControl struct {
	Control  uint32
	_        uint32
	DebugReg [8]uint64
}

func (vcpu *vcpu) SingleStep(onoff bool) error {
	const (
		// Enable enables debug options in the guest
		Enable = 1
		// SingleStep enables single step.
		SingleStep = 2
	)

	debug := debugControl{
		Control: Enable | SingleStep,
	}
	if !onoff {
		debug.Control = 0
	}
	setGuestDebug := IIOW(0x9b, unsafe.Sizeof(debugControl{}))

	_, err := Ioctl(vcpu.fd, setGuestDebug, uintptr(unsafe.Pointer(&debug)))

	return err
}
