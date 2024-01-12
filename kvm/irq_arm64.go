package kvm

import (
	"fmt"
	"unsafe"
)

const (
	_GIC_SGI_IRQ_BASE = 0
	_GIC_PPI_IRQ_BASE = 16
	_GIC_SPI_IRQ_BASE = 32

	_GIC_FDT_IRQ_NUM_CELLS = 3

	_GIC_FDT_IRQ_TYPE_SPI = 0
	_GIC_FDT_IRQ_TYPE_PPI = 1

	_GIC_FDT_IRQ_PPI_CPU_SHIFT = 8
	_GIC_FDT_IRQ_PPI_CPU_MASK  = (0xff << _GIC_FDT_IRQ_PPI_CPU_SHIFT)

	_GIC_CPUI_CTLR_EN      = (1 << 0)
	_GIC_CPUI_PMR_MIN_PRIO = 0xff

	_GIC_CPUI_OFF_PMR = 4

	_GIC_MAX_CPUS = 8
	_GIC_MAX_IRQ  = 255

	_GIC_DIST_SIZE   = 0x10000
	_GIC_CPUI_SIZE   = 0x20000
	_GIC_REDIST_SIZE = 0x20000

	_GIC_DIST_BASE = physRamBase - _GIC_DIST_SIZE
	_GIC_CPUI_BASE = _GIC_DIST_BASE - _GIC_CPUI_SIZE

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
	cpuiAddr := _GIC_CPUI_BASE
	distAddr := _GIC_DIST_BASE
	redistSize := len(m.vm.vcpus) * _GIC_REDIST_SIZE
	redistBase := _GIC_DIST_BASE - redistSize

	gicDevice := CreateDevice{
		flags: 0,
	}

	cpuiAttr := DeviceAttr{
		group: _KVM_DEV_ARM_VGIC_GRP_ADDR,
		attr:  _KVM_VGIC_V2_ADDR_TYPE_CPU,
		addr:  uint64(uintptr(unsafe.Pointer(&cpuiAddr))),
	}
	distAttr := DeviceAttr{
		group: _KVM_DEV_ARM_VGIC_GRP_ADDR,
		addr:  uint64(uintptr(unsafe.Pointer(&distAddr))),
	}
	redistAttr := DeviceAttr{
		group: _KVM_DEV_ARM_VGIC_GRP_ADDR,
		attr:  _KVM_VGIC_V3_ADDR_TYPE_REDIST,
		addr:  uint64(uintptr(unsafe.Pointer(&redistBase))),
	}

	switch irq {
	case GICv2:
		gicDevice.typ = _KVM_DEV_TYPE_ARM_VGIC_V2
		distAttr.attr = _KVM_VGIC_V2_ADDR_TYPE_DIST
	case GICv3:
		gicDevice.typ = _KVM_DEV_TYPE_ARM_VGIC_V3
		distAttr.attr = _KVM_VGIC_V3_ADDR_TYPE_DIST
	}

	_, err := Ioctl(m.vm.fd, IIOWR(kvmCreateDevice, unsafe.Sizeof(gicDevice)), uintptr(unsafe.Pointer(&gicDevice)))
	if err != nil {
		return fmt.Errorf("KVM_CREATE_DEVICE: %w", err)
	}

	// TODO: close gicDevice.fd on error

	switch irq {
	case GICv2:
		_, err = Ioctl(uintptr(gicDevice.fd), IIOW(kvmSetDeviceAttr, unsafe.Sizeof(cpuiAttr)), uintptr(unsafe.Pointer(&cpuiAttr)))
	case GICv3:
		_, err = Ioctl(uintptr(gicDevice.fd), IIOW(kvmSetDeviceAttr, unsafe.Sizeof(redistAttr)), uintptr(unsafe.Pointer(&redistAttr)))
	}
	if err != nil {
		return err
	}

	_, err = Ioctl(uintptr(gicDevice.fd), IIOW(kvmSetDeviceAttr, unsafe.Sizeof(distAttr)), uintptr(unsafe.Pointer(&distAttr)))
	if err != nil {
		return err
	}

	lines := 32
	nrIrqs := _GIC_SPI_IRQ_BASE + lines
	nrIrqsAttr := DeviceAttr{
		group: _KVM_DEV_ARM_VGIC_GRP_NR_IRQS,
		addr:  uint64(uintptr(unsafe.Pointer(&nrIrqs))),
	}
	vgicInitAttr := DeviceAttr{
		group: _KVM_DEV_ARM_VGIC_GRP_CTRL,
		attr:  _KVM_DEV_ARM_VGIC_CTRL_INIT,
	}

	hasIrqs, err := Ioctl(uintptr(gicDevice.fd), IIOW(kvmHasDeviceAttr, unsafe.Sizeof(nrIrqsAttr)), uintptr(unsafe.Pointer(&nrIrqsAttr)))
	if err != nil {
		return fmt.Errorf("KVM_HAS_DEVICE_ATTR: %w", err)
	} else if hasIrqs == 0 {
		_, err := Ioctl(uintptr(gicDevice.fd), IIOW(kvmSetDeviceAttr, unsafe.Sizeof(nrIrqsAttr)), uintptr(unsafe.Pointer(&nrIrqsAttr)))
		if err != nil {
			return fmt.Errorf("KVM_SET_DEVICE_ATTR: %w", err)
		}
	}

	hasInit, err := Ioctl(uintptr(gicDevice.fd), IIOW(kvmHasDeviceAttr, unsafe.Sizeof(vgicInitAttr)), uintptr(unsafe.Pointer(&vgicInitAttr)))
	if err != nil {
		return fmt.Errorf("KVM_HAS_DEVICE_ATTR: %w", err)
	} else if hasInit == 0 {
		_, err := Ioctl(uintptr(gicDevice.fd), IIOW(kvmSetDeviceAttr, unsafe.Sizeof(vgicInitAttr)), uintptr(unsafe.Pointer(&vgicInitAttr)))
		if err != nil {
			return fmt.Errorf("KVM_SET_DEVICE_ATTR: %w", err)
		}
	}

	return nil
}

type ArmDeviceAddr struct {
	id   uint64
	addr uint64
}

func (m *Machine) createIrqChip() error {
	gicAddr := [2]ArmDeviceAddr{
		{
			id:   kvmVGICV2AddrTypeDist | (kvmArmDeviceVGICV2 << kvmArmDeviceIDShift),
			addr: _GIC_DIST_BASE,
		},
		{
			id:   kvmVGICV2AddrTypeDist | (kvmArmDeviceVGICV2 << kvmArmDeviceIDShift),
			addr: _GIC_CPUI_BASE,
		},
	}

	_, err := Ioctl(m.vm.fd, IIO(kvmCreateIRQChip), 0)
	if err != nil {
		return fmt.Errorf("KVM_CREATE_IRQCHIP: %w", err)
	}
	_, err = Ioctl(m.vm.fd, IIOW(kvmArmSetDeviceAddr, unsafe.Sizeof(ArmDeviceAddr{})), uintptr(unsafe.Pointer(&gicAddr[0])))
	if err != nil {
		return fmt.Errorf("KVM_ARM_SET_DEVICE_ADDR: %w", err)
	}
	_, err = Ioctl(m.vm.fd, IIOW(kvmArmSetDeviceAddr, unsafe.Sizeof(ArmDeviceAddr{})), uintptr(unsafe.Pointer(&gicAddr[1])))
	if err != nil {
		return fmt.Errorf("KVM_ARM_SET_DEVICE_ADDR: %w", err)
	}
	return nil
}

func (m *Machine) createIrqController(irq IrqType) error {
	err := m.createDevice(irq)
	if err != nil && irq == GICv2 {
		return m.createIrqChip()
	}

	return err
}

// func (m *Machine) irqLine(irq, level int) {
// 	lvl := IrqLevel{
// 		irq:
// 	}
// }

func (m *Machine) irqTrigger(irq int) {

}
