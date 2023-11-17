package kvm

import "unsafe"

// Regs are registers for both 386 and amd64.
// In 386 mode, only some of them are used.
type Regs struct {
	RAX    uint64
	RBX    uint64
	RCX    uint64
	RDX    uint64
	RSI    uint64
	RDI    uint64
	RSP    uint64
	RBP    uint64
	R8     uint64
	R9     uint64
	R10    uint64
	R11    uint64
	R12    uint64
	R13    uint64
	R14    uint64
	R15    uint64
	RIP    uint64
	RFLAGS uint64
}

// GetRegs gets the general purpose registers for a vcpu.
func (vcpu *VCPU) GetRegs() (*Regs, error) {
	regs := &Regs{}
	_, err := Ioctl(vcpu.fd, IIOR(kvmGetRegs, unsafe.Sizeof(Regs{})), uintptr(unsafe.Pointer(regs)))

	return regs, err
}

// SetRegs sets the general purpose registers for a vcpu.
func (vcpu *VCPU) SetRegs(regs *Regs) error {
	_, err := Ioctl(vcpu.fd, IIOW(kvmSetRegs, unsafe.Sizeof(Regs{})), uintptr(unsafe.Pointer(regs)))

	return err
}

// Sregs are control registers, for memory mapping for the most part.
type Sregs struct {
	CS              Segment
	DS              Segment
	ES              Segment
	FS              Segment
	GS              Segment
	SS              Segment
	TR              Segment
	LDT             Segment
	GDT             Descriptor
	IDT             Descriptor
	CR0             uint64
	CR2             uint64
	CR3             uint64
	CR4             uint64
	CR8             uint64
	EFER            uint64
	ApicBase        uint64
	InterruptBitmap [(numInterrupts + 63) / 64]uint64
}

// GetSRegs gets the special registers for a vcpu.
func (vcpu *VCPU) GetSregs() (*Sregs, error) {
	sregs := &Sregs{}
	_, err := Ioctl(vcpu.fd, IIOR(kvmGetSregs, unsafe.Sizeof(Sregs{})), uintptr(unsafe.Pointer(sregs)))

	return sregs, err
}

// SetSRegs sets the special registers for a vcpu.
func (vcpu *VCPU) SetSregs(sregs *Sregs) error {
	_, err := Ioctl(vcpu.fd, IIOW(kvmSetSregs, unsafe.Sizeof(Sregs{})), uintptr(unsafe.Pointer(sregs)))

	return err
}

// Segment is an x86 segment descriptor.
type Segment struct {
	Base     uint64
	Limit    uint32
	Selector uint16
	Typ      uint8
	Present  uint8
	DPL      uint8
	DB       uint8
	S        uint8
	L        uint8
	G        uint8
	AVL      uint8
	Unusable uint8
	_        uint8
}

// Descriptor defines a GDT, LDT, or other pointer type.
type Descriptor struct {
	Base  uint64
	Limit uint16
	_     [3]uint16
}

type DebugRegs struct {
	DB    [4]uint64
	DR6   uint64
	DR7   uint64
	Flags uint64
	_     [9]uint64
}

// GetDebugRegs reads debug registers from a vcpu.
func (vcpu *VCPU) GetDebugRegs(dregs *DebugRegs) error {
	_, err := Ioctl(vcpu.fd,
		IIOR(kvmGetDebugRegs, unsafe.Sizeof(DebugRegs{})),
		uintptr(unsafe.Pointer(dregs)))

	return err
}

// SetDebugRegs sets debug registers on a vcpu.
func (vcpu *VCPU) SetDebugRegs(dregs *DebugRegs) error {
	_, err := Ioctl(vcpu.fd,
		IIOW(kvmSetDebugRegs, unsafe.Sizeof(DebugRegs{})),
		uintptr(unsafe.Pointer(dregs)))

	return err
}

type XRC struct {
	XRC   uint32
	_     uint32
	Value uint64
}

type XCRS struct {
	NrXRCS    uint32
	Flags     uint32
	Registers [16]XRC
	_         [16]uint64
}

// GetXCRS copys current vcpu's xcrs to the userspace.
func (vcpu *VCPU) GetXCRS(xcrs *XCRS) error {
	_, err := Ioctl(vcpu.fd,
		IIOR(kvmGetXCRS, unsafe.Sizeof(XCRS{})),
		uintptr(unsafe.Pointer(xcrs)))

	return err
}

// SetXCRS sets vcpu's xcr to the value userspace specified.
func (vcpu *VCPU) SetXCRS(xcrs *XCRS) error {
	_, err := Ioctl(vcpu.fd,
		IIOW(kvmSetXCRS, unsafe.Sizeof(XCRS{})),
		uintptr(unsafe.Pointer(xcrs)))

	return err
}

type SRegs2 struct {
	CS       Segment
	DS       Segment
	ES       Segment
	FS       Segment
	GS       Segment
	SS       Segment
	TR       Segment
	LDT      Segment
	GDT      Descriptor
	IDT      Descriptor
	CR0      uint64
	CR2      uint64
	CR3      uint64
	CR4      uint64
	CR8      uint64
	EFER     uint64
	APICBase uint64
	Flags    uint64
	PDptrs   [4]uint64
}

// GetSRegs2 retrieves special registers from the VCPU.
func (vcpu *VCPU) GetSRegs2(sreg *SRegs2) error {
	_, err := Ioctl(vcpu.fd,
		IIOR(kvmGetSRegs2, unsafe.Sizeof(SRegs2{})),
		uintptr(unsafe.Pointer(sreg)))

	return err
}

// SetSRegs2 sets special registers of VCPU.
func (vcpu *VCPU) SetSRegs2(sreg *SRegs2) error {
	_, err := Ioctl(vcpu.fd,
		IIOW(kvmSetSRegs2, unsafe.Sizeof(SRegs2{})),
		uintptr(unsafe.Pointer(sreg)))

	return err
}
