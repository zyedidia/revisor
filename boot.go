package revisor

import (
	"io"
	"log"
	"sync"

	"github.com/zyedidia/revisor/kvm"
)

func Boot(m *kvm.Machine, kernel io.ReaderAt, params string, trace bool) error {
	err := m.LoadKernel(kernel, params)
	if err != nil {
		return err
	}

	var wg sync.WaitGroup

	for i := 0; i < m.NCPU(); i++ {
		log.Println("booting vcpu", i)
		m.StartVCPU(i, trace, &wg)
		wg.Add(1)
	}

	wg.Wait()
	return nil
}
