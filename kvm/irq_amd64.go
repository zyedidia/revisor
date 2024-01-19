package kvm

import (
	"fmt"
	"unsafe"
)

type PITConfig struct {
	flags uint32
	pad   [15]uint32
}

func (m *Machine) createIrqController() error {
	_, err := Ioctl(m.vm.fd, IIO(kvmCreateIRQChip), 0)
	if err != nil {
		return fmt.Errorf("KVM_CREATE_IRQCHIP: %w", err)
	}

	pit := PITConfig{
		flags: 0,
	}
	_, err = Ioctl(m.vm.fd, IIOW(kvmCreatePIT2, unsafe.Sizeof(pit)), uintptr(unsafe.Pointer(&pit)))
	if err != nil {
		return fmt.Errorf("KVM_CREATE_PIT2: %w", err)
	}

	return nil
}

func (m *Machine) finalizeIrqController() error {
	return nil
}

type IrqLevel struct {
	irq   uint32
	level uint32
}

func (m *Machine) InjectIrq(irq uint32, level uint32) error {
	lvl := IrqLevel{
		irq:   irq,
		level: level,
	}

	_, err := Ioctl(m.vm.fd, IIOW(kvmIRQLine, unsafe.Sizeof(lvl)), uintptr(unsafe.Pointer(&lvl)))
	if err != nil {
		return fmt.Errorf("KVM_IRQ_LINE: %w", err)
	}

	return nil
}
