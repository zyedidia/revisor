package revisor

import (
	"os"
	"path/filepath"

	"github.com/zyedidia/revisor/kvm"
)

type Container struct {
	dirs    []string
	fdtable map[uint64]*os.File
	nextfd  uint64
}

func NewContainer(dirs []string) *Container {
	for i, dir := range dirs {
		path, err := filepath.Abs(dir)
		if err != nil {
			panic(err)
		}
		dirs[i] = path
	}
	return &Container{
		dirs: dirs,
		fdtable: map[uint64]*os.File{
			0: os.Stdin,
			1: os.Stdout,
			2: os.Stderr,
		},
		nextfd: 3,
	}
}

func (c *Container) Signal(m *kvm.Machine, sig os.Signal) error {
	return m.InjectIrq(16, 1)
}
