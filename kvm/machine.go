package kvm

type Machine struct {
	kvmfd uintptr
	vm    *vm
	runs  []*RunData
}
