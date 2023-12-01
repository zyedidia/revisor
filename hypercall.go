package revisor

import (
	"bytes"
	"errors"
	"fmt"
	"io/fs"
	"log"
	"os"

	"github.com/zyedidia/revisor/kvm"
)

const (
	hypWrite = 0
	hypExit  = 1
	hypOpen  = 2
	hypRead  = 3
	hypClose = 4
	hypLseek = 5
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

var (
	ErrExit             = errors.New("exited")
	ErrUnknownHypercall = errors.New("unknown hypercall")
)

func (c *Container) Hypercall(m *kvm.Machine, cpu int, num, a0, a1, a2, a3, a4, a5 uint64) (uint64, error) {
	switch num {
	case hypWrite:
		fd := a0
		ptr := m.VtoP(cpu, a1)
		size := a2
		if f, ok := c.fdtable[fd]; !ok {
			return errFail, nil
		} else {
			fmt.Fprint(f, string(m.Slice(ptr, ptr+size)))
			return size, nil
		}
	case hypLseek:
		fd := a0
		off := int64(a1)
		whence := int(a2)

		if f, ok := c.fdtable[fd]; !ok {
			return errFail, nil
		} else {
			n, err := f.Seek(off, whence)
			if err != nil {
				return errFail, nil
			}
			return uint64(n), nil
		}
	case hypOpen:
		name := cstring(m.SliceEnd(m.VtoP(cpu, a0)))
		flags := a1
		mode := a2

		f, err := os.OpenFile(name, int(flags), fs.FileMode(mode))
		if err != nil {
			return errFail, nil
		}
		fd, err := c.addFile(f)
		if err != nil {
			log.Println(err)
			return errFail, nil
		}
		return fd, nil
	case hypRead:
		fd := a0
		ptr := m.VtoP(cpu, a1)
		size := a2
		if f, ok := c.fdtable[fd]; !ok {
			return errFail, nil
		} else {
			n, err := f.Read(m.Slice(ptr, ptr+size))
			if err != nil {
				return errFail, nil
			}
			return uint64(n), nil
		}
	case hypClose:
		fd := a0
		if _, ok := c.fdtable[fd]; !ok {
			return errFail, nil
		} else {
			delete(c.fdtable, fd)
			return 0, nil
		}
	case hypExit:
		return 0, ErrExit
	}
	return 0, fmt.Errorf("%w: %d", ErrUnknownHypercall, num)
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
