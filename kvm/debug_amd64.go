package kvm

import (
	"fmt"

	"golang.org/x/arch/x86/x86asm"
)

// Inst retrieves an instruction from the guest, at RIP.
// It returns an x86asm.Inst, Ptraceregs, a string in GNU syntax,
// and error.
func (m *Machine) Inst(cpu int) (uint64, string, error) {
	r, err := m.vm.vcpus[cpu].GetRegs()
	if err != nil {
		return 0, "", fmt.Errorf("Inst:Getregs:%w", err)
	}

	pc := r.Rip

	// debug("Inst: pc %#x, sp %#x", pc, sp)
	// We know the PC; grab a bunch of bytes there, then decode and print
	insn := make([]byte, 16)
	if _, err := m.ReadBytes(cpu, insn, pc); err != nil {
		return 0, "", fmt.Errorf("reading PC at #%x:%w", pc, err)
	}

	d, err := x86asm.Decode(insn, 64)
	if err != nil {
		return 0, "", fmt.Errorf("decoding %#02x:%w", insn, err)
	}

	return uint64(r.Rip), x86asm.GNUSyntax(d, r.Rip, nil), nil
}
