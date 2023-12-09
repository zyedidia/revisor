package kvm

import (
	"encoding/binary"
	"errors"
)

type argv struct {
	args []string
}

// returns the vaddr of the argv array
func (k argv) WriteAt(physMem []byte, off uint64) (uint64, error) {
	argp := make([]uint64, 0, len(k.args)+1)
	for _, a := range k.args {
		b := append([]byte(a), 0)
		copy(physMem[off:], b)
		argp = append(argp, pa2ka(physRamBase+off))
		off += uint64(len(b))
	}
	argp = append(argp, 0)

	argv := off
	for _, p := range argp {
		binary.LittleEndian.PutUint64(physMem[off:], p)
		off += 8
	}

	if physRamBase+off > physKernBase {
		return 0, errors.New("argv too large")
	}

	return pa2ka(physRamBase + argv), nil
}
