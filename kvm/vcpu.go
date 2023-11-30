package kvm

import (
	"errors"
	"syscall"
	"unsafe"
)

type vcpu struct {
	fd uintptr
}

func (vcpu *vcpu) Run() error {
	_, err := Ioctl(vcpu.fd, IIO(kvmRun), uintptr(0))
	if err != nil {
		// refs: https://github.com/kvmtool/kvmtool/blob/415f92c33a227c02f6719d4594af6fad10f07abf/kvm-cpu.c#L44
		if errors.Is(err, syscall.EAGAIN) || errors.Is(err, syscall.EINTR) {
			return nil
		}
	}

	return err
}

type Translation struct {
	// input
	LinearAddress uint64

	// output
	PhysicalAddress uint64
	Valid           uint8
	Writeable       uint8
	Usermode        uint8
	_               [5]uint8
}

// Translate translates a virtual address according to the vcpu’s current address translation mode.
func (vcpu *vcpu) Translate(t *Translation) error {
	_, err := Ioctl(vcpu.fd,
		IIOWR(kvmTranslate, unsafe.Sizeof(Translation{})),
		uintptr(unsafe.Pointer(t)))

	return err
}

func (vcpu *vcpu) VtoP(v uint64) uint64 {
	t := &Translation{
		LinearAddress: v,
	}
	err := vcpu.Translate(t)
	if err != nil {
		panic(err)
	}
	return t.PhysicalAddress
}
