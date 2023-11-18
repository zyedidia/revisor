package kvm

import (
	"fmt"
	"unsafe"

	"golang.org/x/arch/x86/x86asm"
)

// debugControl controls guest debug.
type debugControl struct {
	Control  uint32
	_        uint32
	DebugReg [8]uint64
}

func (vcpu *VCPU) SingleStep(onoff bool) error {
	const (
		// Enable enables debug options in the guest
		Enable = 1
		// SingleStep enables single step.
		SingleStep = 2
	)

	var (
		debug         [unsafe.Sizeof(debugControl{})]byte
		setGuestDebug = IIOW(0x9b, unsafe.Sizeof(debugControl{}))
	)

	if onoff {
		debug[2] = 0x0002 // 0000
		debug[0] = Enable | SingleStep
	}

	// this is not very nice, but it is easy.
	// And TBH, the tricks the Linux kernel people
	// play are a lot nastier.
	_, err := Ioctl(vcpu.fd, setGuestDebug, uintptr(unsafe.Pointer(&debug[0])))

	return err
}

// Inst retrieves an instruction from the guest, at RIP.
// It returns an x86asm.Inst, Ptraceregs, a string in GNU syntax,
// and error.
func (m *Machine) Inst(cpu int) (*x86asm.Inst, *Regs, string, error) {
	r, err := m.vm.vcpus[cpu].GetRegs()
	if err != nil {
		return nil, nil, "", fmt.Errorf("Inst:Getregs:%w", err)
	}

	pc := r.RIP

	// debug("Inst: pc %#x, sp %#x", pc, sp)
	// We know the PC; grab a bunch of bytes there, then decode and print
	insn := make([]byte, 16)
	if _, err := m.ReadBytes(cpu, insn, pc); err != nil {
		return nil, nil, "", fmt.Errorf("reading PC at #%x:%w", pc, err)
	}

	d, err := x86asm.Decode(insn, 64)
	if err != nil {
		return nil, nil, "", fmt.Errorf("decoding %#02x:%w", insn, err)
	}

	return &d, r, x86asm.GNUSyntax(d, r.RIP, nil), nil
}
