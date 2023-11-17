package kvm

import (
	"fmt"
	"unsafe"

	"github.com/tysonmote/gommap"
)

type VM struct {
	fd    uintptr
	mem   gommap.MMap
	vcpus []VCPU
}

func NewVM(kvmfd uintptr, memSize int64) (*VM, error) {
	v, err := getAPIVersion(kvmfd)
	if err != nil {
		return nil, err
	}
	if v != 12 {
		return nil, fmt.Errorf("KVM_GET_API_VERISON: got %d, expected 12", v)
	}
	vmfd, err := createVM(kvmfd)
	if err != nil {
		return nil, err
	}
	nofd := -1
	mem, err := gommap.MapAt(0, uintptr(nofd), 0, memSize, gommap.PROT_READ|gommap.PROT_WRITE, gommap.MAP_SHARED|gommap.MAP_ANONYMOUS)
	if err != nil {
		return nil, err
	}

	return &VM{
		fd:  vmfd,
		mem: mem,
	}, nil
}

func (vm *VM) InitMemory() error {
	return vm.SetUserspaceMemoryRegion(&UserspaceMemoryRegion{
		Slot:          0,
		GuestPhysAddr: 0,
		MemorySize:    uint64(len(vm.mem)),
		UserspaceAddr: uint64(uintptr(unsafe.Pointer(&vm.mem[0]))),
	})
}

func (vm *VM) addVCPU() error {
	fd, err := Ioctl(vm.fd, IIO(kvmCreateVCPU), uintptr(len(vm.vcpus)))
	if err != nil {
		return err
	}
	vm.vcpus = append(vm.vcpus, VCPU{
		fd: fd,
	})
	return nil
}

type ClockFlag uint32

const (
	TSCStable ClockFlag = 2
	Realtime  ClockFlag = (1 << 2)
	HostTSC   ClockFlag = (1 << 3)
)

type ClockData struct {
	Clock    uint64
	Flags    uint32
	_        uint32
	Realtime uint64
	HostTSC  uint64
	_        [4]uint32
}

// SetClock sets the current timestamp of kvmclock to the value specified in its parameter.
// In conjunction with GET_CLOCK, it is used to ensure monotonicity on scenarios such as migration.
func (vm *VM) SetClock(cd *ClockData) error {
	_, err := Ioctl(vm.fd,
		IIOW(kvmSetClock, unsafe.Sizeof(ClockData{})),
		uintptr(unsafe.Pointer(cd)))

	return err
}

// GetClock gets the current timestamp of kvmclock as seen by the current guest.
// In conjunction with SET_CLOCK, it is used to ensure monotonicity on scenarios such as migration.
func (vm *VM) GetClock(cd *ClockData) error {
	_, err := Ioctl(vm.fd,
		IIOR(kvmGetClock, unsafe.Sizeof(ClockData{})),
		uintptr(unsafe.Pointer(cd)))

	return err
}
