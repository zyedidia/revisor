package kvm

import (
	"errors"
	"fmt"
	"unsafe"
)

const (
	_GIC_BASE      = 0x100000
	_GIC_DIST_BASE = _GIC_BASE
	_GIC_DIST_SIZE = 0x10000

	_GIC_REDIST_CPUI_BASE = _GIC_DIST_BASE + _GIC_DIST_SIZE
	_GIC_REDIST_CPUI_SIZE = 0x20000

	_KVM_DEV_ARM_VGIC_GRP_ADDR    = 0
	_KVM_VGIC_V2_ADDR_TYPE_DIST   = 0
	_KVM_VGIC_V2_ADDR_TYPE_CPU    = 1
	_KVM_VGIC_V3_ADDR_TYPE_DIST   = 2
	_KVM_VGIC_V3_ADDR_TYPE_REDIST = 3

	_KVM_DEV_TYPE_ARM_VGIC_V2 = 5
	_KVM_DEV_TYPE_ARM_VGIC_V3 = 7

	_KVM_DEV_ARM_VGIC_CTRL_INIT   = 0
	_KVM_DEV_ARM_VGIC_GRP_NR_IRQS = 3
	_KVM_DEV_ARM_VGIC_GRP_CTRL    = 4
)

type IrqType byte

const (
	GICv2 IrqType = iota
	GICv3
)

type CreateDevice struct {
	typ   uint32
	fd    uint32
	flags uint32
}

type DeviceAttr struct {
	flags uint32
	group uint32
	attr  uint64
	addr  uint64
}

func (m *Machine) createDevice(irq IrqType) error {
	distAddr := _GIC_DIST_BASE
	redistAddr := _GIC_REDIST_CPUI_BASE

	device := CreateDevice{
		typ: _KVM_DEV_TYPE_ARM_VGIC_V3,
	}
	distAttr := DeviceAttr{
		group: _KVM_DEV_ARM_VGIC_GRP_ADDR,
		attr:  _KVM_VGIC_V3_ADDR_TYPE_DIST,
		addr:  uint64(uintptr(unsafe.Pointer(&distAddr))),
	}
	redistAttr := DeviceAttr{
		group: _KVM_DEV_ARM_VGIC_GRP_ADDR,
		attr:  _KVM_VGIC_V3_ADDR_TYPE_REDIST,
		addr:  uint64(uintptr(unsafe.Pointer(&redistAddr))),
	}

	_, err := Ioctl(m.vm.fd, IIOWR(kvmCreateDevice, unsafe.Sizeof(device)), uintptr(unsafe.Pointer(&device)))
	if err != nil {
		return fmt.Errorf("KVM_CREATE_DEVICE: %w", err)
	}

	// TODO: close device.fd on error

	m.irqfd = uintptr(device.fd)

	switch irq {
	case GICv3:
		_, err = Ioctl(m.irqfd, IIOW(kvmSetDeviceAttr, unsafe.Sizeof(distAttr)), uintptr(unsafe.Pointer(&distAttr)))
	}
	if err != nil {
		return fmt.Errorf("GIC distributor: %w", err)
	}

	_, err = Ioctl(m.irqfd, IIOW(kvmSetDeviceAttr, unsafe.Sizeof(redistAttr)), uintptr(unsafe.Pointer(&redistAttr)))
	if err != nil {
		return fmt.Errorf("GIC redistributor: %w", err)
	}

	return nil
}

type ArmDeviceAddr struct {
	id   uint64
	addr uint64
}

func (m *Machine) createIrqChip() error {
	return errors.New("GICv2: unimplemented")
}

func (m *Machine) createIrqController(irq IrqType) error {
	err := m.createDevice(irq)
	if err != nil && irq == GICv2 {
		return m.createIrqChip()
	}

	return err
}

func (m *Machine) finalizeIrqController() error {
	vgicInitAttr := DeviceAttr{
		group: _KVM_DEV_ARM_VGIC_GRP_CTRL,
		attr:  _KVM_DEV_ARM_VGIC_CTRL_INIT,
	}
	_, err := Ioctl(m.irqfd, IIOW(kvmSetDeviceAttr, unsafe.Sizeof(vgicInitAttr)), uintptr(unsafe.Pointer(&vgicInitAttr)))
	if err != nil {
		return fmt.Errorf("VGIC_INIT_ATTR: %w", err)
	}
	return nil
}

// func (m *Machine) irqLine(irq, level int) {
// 	lvl := IrqLevel{
// 		irq:
// 	}
// }

func (m *Machine) irqTrigger(irq int) {

}
