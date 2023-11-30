package kvm

const (
	kvmGetAPIVersion     = 0x00
	kvmCreateVM          = 0x1
	kvmGetMSRIndexList   = 0x02
	kvmCheckExtension    = 0x03
	kvmGetVCPUMMapSize   = 0x04
	kvmGetSupportedCPUID = 0x05

	kvmGetEmulatedCPUID       = 0x09
	kvmGetMSRFeatureIndexList = 0x0A

	kvmCreateVCPU          = 0x41
	kvmGetDirtyLog         = 0x42
	kvmSetNrMMUPages       = 0x44
	kvmGetNrMMUPages       = 0x45
	kvmSetUserMemoryRegion = 0x46
	kvmSetTSSAddr          = 0x47
	kvmSetIdentityMapAddr  = 0x48

	kvmCreateIRQChip = 0x60
	kvmGetIRQChip    = 0x62
	kvmSetIRQChip    = 0x63
	kvmIRQLineStatus = 0x67

	kvmResgisterCoalescedMMIO   = 0x67
	kvmUnResgisterCoalescedMMIO = 0x68

	kvmSetGSIRouting = 0x6A

	kvmReinjectControl = 0x71
	kvmCreatePIT2      = 0x77
	kvmSetClock        = 0x7B
	kvmGetClock        = 0x7C

	kvmRun       = 0x80
	kvmGetRegs   = 0x81
	kvmSetRegs   = 0x82
	kvmGetSregs  = 0x83
	kvmSetSregs  = 0x84
	kvmTranslate = 0x85
	kvmInterrupt = 0x86

	kvmGetMSRS = 0x88
	kvmSetMSRS = 0x89

	kvmGetLAPIC = 0x8e
	kvmSetLAPIC = 0x8f

	kvmSetCPUID2          = 0x90
	kvmGetCPUID2          = 0x91
	kvmTRPAccessReporting = 0x92

	kvmGetMPState = 0x98
	kvmSetMPState = 0x99

	kvmX86SetupMCE           = 0x9C
	kvmX86GetMCECapSupported = 0x9D

	kvmGetPIT2 = 0x9F
	kvmSetPIT2 = 0xA0

	kvmGetVCPUEvents = 0x9F
	kvmSetVCPUEvents = 0xA0

	kvmGetDebugRegs = 0xA1
	kvmSetDebugRegs = 0xA2

	kvmSetTSCKHz = 0xA2
	kvmGetTSCKHz = 0xA3

	kvmGetXCRS = 0xA6
	kvmSetXCRS = 0xA7

	kvmSMI = 0xB7

	kvmGetSRegs2 = 0xCC
	kvmSetSRegs2 = 0xCD

	kvmCreateDev = 0xE0
)

type ExitType uint

const (
	ExitUnknown       ExitType = 0
	ExitException     ExitType = 1
	ExitIO            ExitType = 2
	ExitHypercall     ExitType = 3
	ExitDebug         ExitType = 4
	ExitHlt           ExitType = 5
	ExitMMIO          ExitType = 6
	ExitIRQWindowOpen ExitType = 7
	ExitShutdown      ExitType = 8
	ExitFailEntry     ExitType = 9
	ExitIntr          ExitType = 10
	ExitSetTPR        ExitType = 11
	ExitTPRAccess     ExitType = 12
	ExitDCR           ExitType = 15
	ExitNMI           ExitType = 16
	ExitInternalError ExitType = 17
)

const (
	numInterrupts = 0x100
)

func getAPIVersion(kvmfd uintptr) (uintptr, error) {
	return Ioctl(kvmfd, IIO(kvmGetAPIVersion), uintptr(0))
}

func createVM(kvmfd uintptr) (uintptr, error) {
	return Ioctl(kvmfd, IIO(kvmCreateVM), uintptr(0))
}
