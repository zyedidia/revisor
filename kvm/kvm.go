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
	EXITUNKNOWN       ExitType = 0
	EXITEXCEPTION     ExitType = 1
	EXITIO            ExitType = 2
	EXITHYPERCALL     ExitType = 3
	EXITDEBUG         ExitType = 4
	EXITHLT           ExitType = 5
	EXITMMIO          ExitType = 6
	EXITIRQWINDOWOPEN ExitType = 7
	EXITSHUTDOWN      ExitType = 8
	EXITFAILENTRY     ExitType = 9
	EXITINTR          ExitType = 10
	EXITSETTPR        ExitType = 11
	EXITTPRACCESS     ExitType = 12
	EXITS390SIEIC     ExitType = 13
	EXITS390RESET     ExitType = 14
	EXITDCR           ExitType = 15
	EXITNMI           ExitType = 16
	EXITINTERNALERROR ExitType = 17

	EXITIOIN  = 0
	EXITIOOUT = 1
)

const (
	numInterrupts   = 0x100
	CPUIDFeatures   = 0x40000001
	CPUIDSignature  = 0x40000000
	CPUIDFuncPerMon = 0x0A
)

// RunData defines the data used to run a VM.
type RunData struct {
	RequestInterruptWindow     uint8
	ImmediateExit              uint8
	_                          [6]uint8
	ExitReason                 uint32
	ReadyForInterruptInjection uint8
	IfFlag                     uint8
	_                          [2]uint8
	CR8                        uint64
	ApicBase                   uint64
	Data                       [32]uint64
}

const (
	/*
		Start low ram range
	*/
	// LowRAMStart (start: 0, length: 640KiB).
	LowRAMStart = 0x0

	// Location of EBDA address.
	EBDAPointer = 0x40e

	// Initial GDT/IDT.
	BootGDTStart = 0x500
	BootIDTStart = 0x520

	// Address of the pvh_info struct.
	PVHInfoStart = 0x6000

	// Address of hvm_modlist_entry type.
	PVHModlistStart = 0x6040

	// Address of memory map table for PVH boot.
	PVHMemMapStart = 0x7000

	// Kernel command line.
	KernelCmdLine        = 0x2_0000
	KernelCmdLineSizeMax = 0x1_0000

	// MPTable describing vcpus.
	MPTableStart = 0x9_FC00

	/*
		End low ram range.
	*/

	// EDBA reserved area (start: 640KiB, length: 384KiB).
	EBDAStart = 0xA_0000

	// RSDPPointer in EDBA area.
	RSDPPointer = EBDAStart

	// SMBIOSStart first location possible for SMBIOS.
	SMBIOSStart = 0xF_0000

	/*
		Start high ram range.
	*/

	// HighRAMStart (start: 1MiB, length: 3071MiB).
	HighRAMStart = 0x10_0000

	// 32Bit reserved area (start: 3GiB, length: 896MiB).
	Mem32BitReservedStart = 0xC000_0000
	Mem32BitReservedSize  = PCIMMConfigSize + Mem32BitDeviceSize

	Mem32BitDeviceStart = Mem32BitReservedStart
	Mem32BitDeviceSize  = 640 << 20

	// PCI Memory Mapped Config Space.
	PCIMMConfigStart            = Mem32BitDeviceStart + Mem32BitDeviceSize
	PCIMMConfigSize             = 256 << 20
	PCIMMIOConfigSizePerSegment = 4096 * 256

	// TSS is 3 page after PCI MMConfig space.
	KVMTSSStart = PCIMMConfigStart + PCIMMConfigSize
	KVMTSSSize  = (3 * 4) << 10

	// Identity map is one page region after TSS.
	KVMIdentityMapStart = KVMTSSStart + KVMTSSSize
	KVMIdentityMapSize  = 4 << 10

	// IOAPIC.
	IOAPICStart = 0xFEC0_0000
	IOAPICSize  = 0x20

	// APIC.
	APICStart = 0xFEE0_0000

	// 64bit address space start.
	RAM64BitStart = 0x1_0000_0000
)

const (
	// Reserve 1 MiB for platform MMIO devices (e.g. ACPI control devices).
	PlatformDeviceAreaSize = 1 << 20
)
