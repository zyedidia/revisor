package kvm

type VCPU struct {
	fd uintptr
}

func (vcpu *VCPU) SetTSCKHz(freq uint64) error {
	_, err := Ioctl(vcpu.fd,
		IIO(kvmSetTSCKHz), uintptr(freq))

	return err
}

func (vcpu *VCPU) GetTSCKHz() (uint64, error) {
	ret, err := Ioctl(vcpu.fd,
		IIO(kvmGetTSCKHz), 0)
	if err != nil {
		return 0, err
	}

	return uint64(ret), nil
}
