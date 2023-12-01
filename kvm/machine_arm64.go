package kvm

func (m *Machine) init() error {
	// TODO: call KVM_ARM_VCPU_INIT and possibly KVM_ARM_PREFERRED_TARGET
	return nil
}

func (m *Machine) SetupRegs(pc, cmdline uint64) error {
	// TODO: setup regs
	return nil
}
