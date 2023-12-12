package kvm

import (
	"unsafe"
)

func (vcpu *vcpu) initRegs(rip, argc, argv, memsz uint64) error {
	regs, err := vcpu.GetRegs()
	if err != nil {
		return err
	}

	// Clear all FLAGS bits, except bit 1 which is always set.
	regs.Rflags = 2
	regs.Rip = rip
	regs.Rdi = memsz
	regs.Rsi = argc
	regs.R15 = argv

	if err := vcpu.SetRegs(regs); err != nil {
		return err
	}

	return nil
}

func (vcpu *vcpu) initSregs(mem []byte) error {
	sregs, err := vcpu.GetSregs()
	if err != nil {
		return err
	}

	// set all segment flat
	sregs.Cs.Base, sregs.Cs.Limit, sregs.Cs.G = 0, 0xFFFFFFFF, 1
	sregs.Ds.Base, sregs.Ds.Limit, sregs.Ds.G = 0, 0xFFFFFFFF, 1
	sregs.Fs.Base, sregs.Fs.Limit, sregs.Fs.G = 0, 0xFFFFFFFF, 1
	sregs.Gs.Base, sregs.Gs.Limit, sregs.Gs.G = 0, 0xFFFFFFFF, 1
	sregs.Es.Base, sregs.Es.Limit, sregs.Es.G = 0, 0xFFFFFFFF, 1
	sregs.Ss.Base, sregs.Ss.Limit, sregs.Ss.G = 0, 0xFFFFFFFF, 1

	sregs.Cs.Db, sregs.Ss.Db = 1, 1
	sregs.Cr0 |= 1 // protected mode
	sregs.Cr0 &= 0xfffb
	sregs.Cr0 |= CR0xMP
	sregs.Cr4 = CR4xOSFXSR | CR4xOSXMMEXCPT // enable SSE

	if err := vcpu.SetSregs(sregs); err != nil {
		return err
	}

	return nil
}

// Regs are registers for both 386 and amd64.
// In 386 mode, only some of them are used.
type Regs struct {
	Rax    uint64
	Rbx    uint64
	Rcx    uint64
	Rdx    uint64
	Rsi    uint64
	Rdi    uint64
	Rsp    uint64
	Rbp    uint64
	R8     uint64
	R9     uint64
	R10    uint64
	R11    uint64
	R12    uint64
	R13    uint64
	R14    uint64
	R15    uint64
	Rip    uint64
	Rflags uint64
}

// GetRegs gets the general purpose registers for a vcpu.
func (vcpu *vcpu) GetRegs() (*Regs, error) {
	regs := &Regs{}
	_, err := Ioctl(vcpu.fd, IIOR(kvmGetRegs, unsafe.Sizeof(Regs{})), uintptr(unsafe.Pointer(regs)))

	return regs, err
}

// SetRegs sets the general purpose registers for a vcpu.
func (vcpu *vcpu) SetRegs(regs *Regs) error {
	_, err := Ioctl(vcpu.fd, IIOW(kvmSetRegs, unsafe.Sizeof(Regs{})), uintptr(unsafe.Pointer(regs)))

	return err
}

// Sregs are control registers, for memory mapping for the most part.
type Sregs struct {
	Cs              Segment
	Ds              Segment
	Es              Segment
	Fs              Segment
	Gs              Segment
	Ss              Segment
	Tr              Segment
	Ldt             Segment
	Gdt             Descriptor
	Idt             Descriptor
	Cr0             uint64
	Cr2             uint64
	Cr3             uint64
	Cr4             uint64
	Cr8             uint64
	Efer            uint64
	ApicBase        uint64
	InterruptBitmap [(numInterrupts + 63) / 64]uint64
}

// GetSRegs gets the special registers for a vcpu.
func (vcpu *vcpu) GetSregs() (*Sregs, error) {
	sregs := &Sregs{}
	_, err := Ioctl(vcpu.fd, IIOR(kvmGetSregs, unsafe.Sizeof(Sregs{})), uintptr(unsafe.Pointer(sregs)))

	return sregs, err
}

// SetSRegs sets the special registers for a vcpu.
func (vcpu *vcpu) SetSregs(sregs *Sregs) error {
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
	Dpl      uint8
	Db       uint8
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
	Db    [4]uint64
	Dr6   uint64
	Dr7   uint64
	Flags uint64
	_     [9]uint64
}

// GetDebugRegs reads debug registers from a vcpu.
func (vcpu *vcpu) GetDebugRegs(dregs *DebugRegs) error {
	_, err := Ioctl(vcpu.fd,
		IIOR(kvmGetDebugRegs, unsafe.Sizeof(DebugRegs{})),
		uintptr(unsafe.Pointer(dregs)))

	return err
}

// SetDebugRegs sets debug registers on a vcpu.
func (vcpu *vcpu) SetDebugRegs(dregs *DebugRegs) error {
	_, err := Ioctl(vcpu.fd,
		IIOW(kvmSetDebugRegs, unsafe.Sizeof(DebugRegs{})),
		uintptr(unsafe.Pointer(dregs)))

	return err
}

type SRegs2 struct {
	Cs       Segment
	Ds       Segment
	Es       Segment
	Fs       Segment
	Gs       Segment
	Ss       Segment
	Tr       Segment
	Ldt      Segment
	Gdt      Descriptor
	Idt      Descriptor
	Cr0      uint64
	Cr2      uint64
	Cr3      uint64
	Cr4      uint64
	Cr8      uint64
	Efer     uint64
	ApicBase uint64
	Flags    uint64
	PdPtrs   [4]uint64
}

// GetSRegs2 retrieves special registers from the VCPU.
func (vcpu *vcpu) GetSRegs2(sreg *SRegs2) error {
	_, err := Ioctl(vcpu.fd,
		IIOR(kvmGetSRegs2, unsafe.Sizeof(SRegs2{})),
		uintptr(unsafe.Pointer(sreg)))

	return err
}

// SetSRegs2 sets special registers of VCPU.
func (vcpu *vcpu) SetSRegs2(sreg *SRegs2) error {
	_, err := Ioctl(vcpu.fd,
		IIOW(kvmSetSRegs2, unsafe.Sizeof(SRegs2{})),
		uintptr(unsafe.Pointer(sreg)))

	return err
}

func (vcpu *vcpu) GetPc() uint64 {
	r, _ := vcpu.GetRegs()
	return r.Rip
}
