package ivis

import (
	"bytes"
	"errors"
	"fmt"
	"io/fs"
	"log"
	"os"

	"github.com/zyedidia/ivis/kvm"
)

const (
	hypWrite = 0
	hypExit  = 1
	hypOpen  = 2
	hypRead  = 3
	hypClose = 4
)

const (
	errFail = ^uint64(0)

	fdMax = 1024 * 1024
)

type Container struct {
	fdtable map[uint64]*os.File
	nextfd  uint64
}

func NewContainer() *Container {
	return &Container{
		fdtable: map[uint64]*os.File{
			0: os.Stdin,
			1: os.Stdout,
			2: os.Stderr,
		},
		nextfd: 3,
	}
}

func (c *Container) addFile(f *os.File) (uint64, error) {
	if c.nextfd >= fdMax {
		return 0, errors.New("reached maximum number of file descriptors")
	}
	fd := c.nextfd
	c.fdtable[fd] = f
	c.nextfd++
	return fd, nil
}

func (c *Container) Hypercall(regs *kvm.Regs, mem []byte) bool {
	switch regs.RAX {
	case hypWrite:
		fd := regs.RDI
		ptr := regs.RSI
		size := regs.RDX
		if f, ok := c.fdtable[fd]; !ok {
			regs.RAX = errFail
		} else {
			fmt.Fprint(f, string(mem[ptr:ptr+size]))
			regs.RAX = size
		}
	case hypOpen:
		name := cstring(mem[regs.RDI:])
		flags := regs.RSI
		mode := regs.RDX

		f, err := os.OpenFile(name, int(flags), fs.FileMode(mode))
		if err != nil {
			regs.RAX = errFail
			break
		}
		fd, err := c.addFile(f)
		if err != nil {
			log.Println(err)
			regs.RAX = errFail
			break
		}
		regs.RAX = fd
	case hypRead:
		fd := regs.RDI
		ptr := regs.RSI
		size := regs.RDX
		if f, ok := c.fdtable[fd]; !ok {
			regs.RAX = errFail
		} else {
			n, err := f.Read(mem[ptr : ptr+size])
			if err != nil {
				regs.RAX = errFail
				break
			}
			regs.RAX = uint64(n)
		}
	case hypClose:
		fd := regs.RDI
		if _, ok := c.fdtable[fd]; !ok {
			regs.RAX = errFail
		} else {
			delete(c.fdtable, fd)
			regs.RAX = 0
		}
	case hypExit:
		return true
	default:
		fmt.Println("unknown hypercall", regs.RAX)
	}
	return false
}

func cstring(data []byte) string {
	buf := &bytes.Buffer{}
	for _, b := range data {
		if b == 0 {
			break
		}
		buf.WriteByte(b)
	}
	return buf.String()
}
