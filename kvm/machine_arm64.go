package kvm

import (
	"fmt"
	"unsafe"
)

type VcpuInit struct {
	target   uint32
	features [7]uint32
}

func (vm *vm) init() error {
	return nil
}

func (m *Machine) init() error {
	var init VcpuInit
	_, err := Ioctl(m.vm.fd, IIOR(kvmArmPreferredTarget, unsafe.Sizeof(VcpuInit{})), uintptr(unsafe.Pointer(&init)))
	if err != nil {
		return fmt.Errorf("KVM_ARM_PREFERRED_TARGET: %w", err)
	}
	for _, vcpu := range m.vm.vcpus {
		_, err = Ioctl(vcpu.fd, IIOW(kvmArmVcpuInit, unsafe.Sizeof(VcpuInit{})), uintptr(unsafe.Pointer(&init)))
		if err != nil {
			return fmt.Errorf("KVM_ARM_VCPU_INIT: %w", err)
		}
	}
	return nil
}

func (m *Machine) SetupRegs(pc, cmdline uint64) error {
	for _, cpu := range m.vm.vcpus {
		if err := cpu.SetPc(pc); err != nil {
			return err
		}
		if err := cpu.SetReg(0, uint64(len(m.vm.mem))); err != nil {
			return err
		}
		if err := cpu.SetReg(1, cmdline); err != nil {
			return err
		}
	}
	return nil
}

func (m *Machine) hypercall(cpu int) error {
	vcpu := m.vm.vcpus[cpu]
	r0, err := m.handler.Hypercall(m, cpu, vcpu.GetReg(8), vcpu.GetReg(0), vcpu.GetReg(1), vcpu.GetReg(2), vcpu.GetReg(3), vcpu.GetReg(4), vcpu.GetReg(5))
	if err != nil {
		return err
	}
	if err := vcpu.SetReg(0, r0); err != nil {
		return err
	}
	return nil
}

func (m *Machine) VtoP(cpu int, v uint64) uint64 {
	// TODO: arm64 virtual to physical translation
	return v
}
