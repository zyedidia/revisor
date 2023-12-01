package kvm

const (
	kvmTSSStart = kvmIdentityMapStart + kvmIdentityMapSize
)

func (m *Machine) init() error {
	if err := m.vm.setTSSAddr(kvmTSSStart); err != nil {
		return err
	}

	// initialize cpuids
	for i := range m.runs {
		if err := m.initCPUID(i); err != nil {
			return err
		}
	}
	return nil
}

// setTSSAddr sets the Task Segment Selector for a vm.
func (vm *vm) setTSSAddr(addr uint32) error {
	_, err := Ioctl(vm.fd, IIO(kvmSetTSSAddr), uintptr(addr))

	return err
}

func (m *Machine) SetupRegs(rip, bp uint64) error {
	for _, cpu := range m.vm.vcpus {
		if err := cpu.initRegs(rip, bp, uint64(len(m.vm.mem))); err != nil {
			return err
		}
		if err := cpu.initSregs(m.vm.mem); err != nil {
			return err
		}
	}
	return nil
}

func (m *Machine) initCPUID(cpu int) error {
	cpuid := CPUID{
		Nent:    100,
		Entries: make([]CPUIDEntry2, 100),
	}

	if err := m.GetSupportedCPUID(&cpuid); err != nil {
		return err
	}

	// https://www.kernel.org/doc/html/v5.7/virt/kvm/cpuid.html
	for i := 0; i < int(cpuid.Nent); i++ {
		if cpuid.Entries[i].Function == CPUIDFuncPerMon {
			cpuid.Entries[i].Eax = 0 // disable
		} else if cpuid.Entries[i].Function == CPUIDSignature {
			cpuid.Entries[i].Eax = CPUIDFeatures
			cpuid.Entries[i].Ebx = 0x4b4d564b // KVMK
			cpuid.Entries[i].Ecx = 0x564b4d56 // VMKV
			cpuid.Entries[i].Edx = 0x4d       // M
		}
	}

	if err := m.vm.vcpus[cpu].SetCPUID2(&cpuid); err != nil {
		return err
	}

	return nil
}
