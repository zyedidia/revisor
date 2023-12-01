package kvm

import (
	"errors"
	"syscall"
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
