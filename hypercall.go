package hypertain

import (
	"fmt"
	"os"

	"github.com/zyedidia/hypertain/kvm"
)

const (
	hypWrite = 0
	hypExit  = 1
)

const (
	errFail = ^uint64(0)
)

func DefaultHandler(regs *kvm.Regs, mem []byte) bool {
	switch regs.RAX {
	case hypWrite:
		fd := regs.RDI
		ptr := regs.RSI
		size := regs.RDX
		if fd != 1 {
			regs.RAX = errFail
			break
		}
		fmt.Fprint(os.Stdout, string(mem[ptr:ptr+size]))
		regs.RAX = size
	case hypExit:
		return true
	default:
		fmt.Println("unknown hypercall", regs.RAX)
	}
	return false
}
