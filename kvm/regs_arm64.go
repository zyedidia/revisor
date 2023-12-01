package kvm

import (
	"fmt"
	"unsafe"
)

type UserRegs struct {
	Regs   [31]uint64
	Sp     uint64
	Pc     uint64
	PState uint64
	SpEl1  uint64
	ElrEl1 uint64
}

type KvmOneReg struct {
	id   uint64
	addr *uint64
}

func (vcpu *vcpu) setReg(id uintptr, val uint64) error {
	reg := KvmOneReg{
		id:   uint64(id),
		addr: &val,
	}
	_, err := Ioctl(vcpu.fd, IIOW(kvmSetOneReg, unsafe.Sizeof(KvmOneReg{})), uintptr(unsafe.Pointer(&reg)))
	if err != nil {
		return fmt.Errorf("KVM_SET_ONE_REG: %w", err)
	}
	return nil
}

func (vcpu *vcpu) getReg(id uintptr) uint64 {
	var val uint64
	reg := KvmOneReg{
		id:   uint64(id),
		addr: &val,
	}
	_, err := Ioctl(vcpu.fd, IIOW(kvmGetOneReg, unsafe.Sizeof(KvmOneReg{})), uintptr(unsafe.Pointer(&reg)))
	if err != nil {
		panic(fmt.Errorf("KVM_GET_ONE_REG: %w", err))
	}
	return val
}

func (vcpu *vcpu) SetPc(pc uint64) error {
	offset := unsafe.Offsetof(UserRegs{}.Pc) / 4
	id := kvmRegArm64 | kvmRegSizeU64 | kvmRegArmCore | offset
	return vcpu.setReg(id, pc)
}

func (vcpu *vcpu) SetReg(i int, val uint64) error {
	offset := (unsafe.Offsetof(UserRegs{}.Regs) + uintptr(i)*8) / 4
	id := kvmRegArm64 | kvmRegSizeU64 | kvmRegArmCore | offset
	return vcpu.setReg(id, val)
}

func (vcpu *vcpu) GetPc() uint64 {
	offset := unsafe.Offsetof(UserRegs{}.Pc) / 4
	id := kvmRegArm64 | kvmRegSizeU64 | kvmRegArmCore | offset
	return vcpu.getReg(id)
}

func (vcpu *vcpu) GetReg(i int) uint64 {
	offset := (unsafe.Offsetof(UserRegs{}.Regs) + uintptr(i)*8) / 4
	id := kvmRegArm64 | kvmRegSizeU64 | kvmRegArmCore | offset
	return vcpu.getReg(id)
}
