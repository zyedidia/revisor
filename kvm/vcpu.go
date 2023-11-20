package kvm

import (
	"errors"
	"fmt"
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

func (vcpu *VCPU) VtoP(v uint64) uint64 {
	t := &Translation{
		LinearAddress: v,
	}
	err := vcpu.Translate(t)
	if err != nil {
		panic(err)
	}
	return t.PhysicalAddress
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

	return fmt.Errorf("expected kernel to boot into protected mode")
}
