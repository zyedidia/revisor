package kvm

const (
	kvmRegArm64   = 0x6000000000000000
	kvmRegSizeU64 = 0x0030000000000000

	kvmRegArmCoprocShift = 16
	kvmRegArmCore        = 0x0010 << kvmRegArmCoprocShift

	kvmArmVcpuInit        = 0xAE
	kvmArmPreferredTarget = 0xAF
)
