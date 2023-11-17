package kvm

import (
	"encoding/hex"
	"errors"
	"log"
	"syscall"
	"unsafe"
)

type VCPU struct {
	fd uintptr
}

func (vcpu *VCPU) SetTSCKHz(freq uint64) error {
	_, err := Ioctl(vcpu.fd,
		IIO(kvmSetTSCKHz), uintptr(freq))

	return err
}

func (vcpu *VCPU) GetTSCKHz() (uint64, error) {
	ret, err := Ioctl(vcpu.fd,
		IIO(kvmGetTSCKHz), 0)
	if err != nil {
		return 0, err
	}

	return uint64(ret), nil
}

func (vcpu *VCPU) Run() error {
	_, err := Ioctl(vcpu.fd, IIO(kvmRun), uintptr(0))
	if err != nil {
		// refs: https://github.com/kvmtool/kvmtool/blob/415f92c33a227c02f6719d4594af6fad10f07abf/kvm-cpu.c#L44
		if errors.Is(err, syscall.EAGAIN) || errors.Is(err, syscall.EINTR) {
			return nil
		}
	}

	return err
}

// Translation is a struct for TRANSLATE queries.
type Translation struct {
	// LinearAddress is input.
	// Most people call this a "virtual address"
	// Intel has their own name.
	LinearAddress uint64

	// This is output
	PhysicalAddress uint64
	Valid           uint8
	Writeable       uint8
	Usermode        uint8
	_               [5]uint8
}

// Translate translates a virtual address according to the vcpu’s current address translation mode.
func (vcpu *VCPU) Translate(t *Translation) error {
	_, err := Ioctl(vcpu.fd,
		IIOWR(kvmTranslate, unsafe.Sizeof(Translation{})),
		uintptr(unsafe.Pointer(t)))

	return err
}

func (vcpu *VCPU) initRegs(rip, bp uint64) error {
	regs, err := vcpu.GetRegs()
	if err != nil {
		return err
	}

	// Clear all FLAGS bits, except bit 1 which is always set.
	regs.RFLAGS = 2
	regs.RIP = rip
	// Create stack which will grow down.
	regs.RSI = bp

	if err := vcpu.SetRegs(regs); err != nil {
		return err
	}

	return nil
}

func (vcpu *VCPU) initSregs(mem []byte, amd64 bool) error {
	sregs, err := vcpu.GetSregs()
	if err != nil {
		return err
	}

	if !amd64 {
		// set all segment flat
		sregs.CS.Base, sregs.CS.Limit, sregs.CS.G = 0, 0xFFFFFFFF, 1
		sregs.DS.Base, sregs.DS.Limit, sregs.DS.G = 0, 0xFFFFFFFF, 1
		sregs.FS.Base, sregs.FS.Limit, sregs.FS.G = 0, 0xFFFFFFFF, 1
		sregs.GS.Base, sregs.GS.Limit, sregs.GS.G = 0, 0xFFFFFFFF, 1
		sregs.ES.Base, sregs.ES.Limit, sregs.ES.G = 0, 0xFFFFFFFF, 1
		sregs.SS.Base, sregs.SS.Limit, sregs.SS.G = 0, 0xFFFFFFFF, 1

		sregs.CS.DB, sregs.SS.DB = 1, 1
		sregs.CR0 |= 1 // protected mode

		if err := vcpu.SetSregs(sregs); err != nil {
			return err
		}

		return nil
	}

	high64k := mem[pageTableBase : pageTableBase+0x6000]

	// zero out the page tables.
	// but we might in fact want to poison them?
	// do we really want 1G, for example?
	for i := range high64k {
		high64k[i] = 0
	}

	// Set up page tables for long mode.
	// take the first six pages of an area it should not touch -- PageTableBase
	// present, read/write, page table at 0xffff0000
	// ptes[0] = PageTableBase + 0x1000 | 0x3
	// 3 in lowest 2 bits means present and read/write
	// 0x60 means accessed/dirty
	// 0x80 means the page size bit -- 0x80 | 0x60 = 0xe0
	// 0x10 here is making it point at the next page.
	copy(high64k, []byte{
		0x03,
		0x10 | uint8((pageTableBase>>8)&0xff),
		uint8((pageTableBase >> 16) & 0xff),
		uint8((pageTableBase >> 24) & 0xff), 0, 0, 0, 0,
	})
	// need four pointers to 2M page tables -- PHYSICAL addresses:
	// 0x2000, 0x3000, 0x4000, 0x5000
	// experiment: set PS bit
	// Don't.
	for i := uint64(0); i < 4; i++ {
		ptb := pageTableBase + (i+2)*0x1000
		copy(high64k[int(i*8)+0x1000:],
			[]byte{
				/*0x80 |*/ 0x63,
				uint8((ptb >> 8) & 0xff),
				uint8((ptb >> 16) & 0xff),
				uint8((ptb >> 24) & 0xff), 0, 0, 0, 0,
			})
	}
	// Now the 2M pages.
	for i := uint64(0); i < 0x1_0000_0000; i += 0x2_00_000 {
		ptb := i | 0xe3
		ix := int((i/0x2_00_000)*8 + 0x2000)
		copy(high64k[ix:], []byte{
			uint8(ptb),
			uint8((ptb >> 8) & 0xff),
			uint8((ptb >> 16) & 0xff),
			uint8((ptb >> 24) & 0xff), 0, 0, 0, 0,
		})
	}

	// set to true to debug.
	if false {
		log.Printf("Page tables: %s", hex.Dump(mem[pageTableBase:pageTableBase+0x3000]))
	}

	sregs.CR3 = uint64(pageTableBase)
	sregs.CR4 = CR4xPAE | CR4xOSFXSR | CR4xOSXMMEXCPT
	sregs.CR0 = CR0xPE | CR0xMP | CR0xET | CR0xNE | CR0xWP | CR0xAM | CR0xPG
	sregs.EFER = EFERxLME | EFERxLMA | EFERxSCE

	seg := Segment{
		Base:     0,
		Limit:    0xffffffff,
		Selector: 1 << 3,
		Typ:      11, /* Code: execute, read, accessed */
		Present:  1,
		DPL:      0,
		DB:       0,
		S:        1, /* Code/data */
		L:        1,
		G:        1, /* 4KB granularity */
		AVL:      0,
	}

	sregs.CS = seg

	seg.Typ = 3 /* Data: read/write, accessed */
	seg.Selector = 2 << 3
	sregs.DS, sregs.ES, sregs.FS, sregs.GS, sregs.SS = seg, seg, seg, seg, seg

	if err := vcpu.SetSregs(sregs); err != nil {
		return err
	}

	return nil
}
