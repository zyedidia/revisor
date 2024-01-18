package kvm

import "fmt"

const (
	kvmRegArm64   = 0x6000000000000000
	kvmRegSizeU64 = 0x0030000000000000

	kvmRegArmCoprocShift = 16
	kvmRegArmCore        = 0x0010 << kvmRegArmCoprocShift

	kvmArmVcpuInit        = 0xAE
	kvmArmPreferredTarget = 0xAF
	kvmArmVCPUFinalize    = 0xC2
	kvmArmVCPUPSCI0_2     = 2
	kvmArmVCPUPMUV3       = 2
	kvmArmSetDeviceAddr   = 0xAB

	kvmVGICV2AddrTypeDist = 0
	kvmArmDeviceVGICV2    = 0
	kvmArmDeviceIDShift   = 16

	kernBase = 0xffff_0000_0000_0000
)

func ka2pa(ka uint64) uint64 {
	if ka >= kernBase {
		return ka - kernBase
	}
	return ka
}

func pa2ka(pa uint64) uint64 {
	return pa + kernBase
}

func createVM(kvmfd uintptr) (uintptr, error) {
	ipa, err := CheckExtension(kvmfd, CapARMVMIPASize)
	if err != nil {
		return 0, fmt.Errorf("ARM_VM_IPA_SIZE: %w", err)
	}
	return Ioctl(kvmfd, IIO(kvmCreateVM), uintptr(ipa&0xff))
}
