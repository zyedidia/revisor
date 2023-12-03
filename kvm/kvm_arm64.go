package kvm

const (
	kvmRegArm64   = 0x6000000000000000
	kvmRegSizeU64 = 0x0030000000000000

	kvmRegArmCoprocShift = 16
	kvmRegArmCore        = 0x0010 << kvmRegArmCoprocShift

	kvmArmVcpuInit        = 0xAE
	kvmArmPreferredTarget = 0xAF
	kvmArmVcpuFinalize    = 0xC2
	kvmArmVcpuPsci0_2     = 2

	kernBase = 0xffff_ffc0_0000_0000
)

func ka2pa(ka uint64) uint64 {
	if ka >= kernBase {
		return ka - kernBase
	}
	return ka
}
