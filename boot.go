package revisor

import (
	"io"
	"log"
	"sync"

	"github.com/zyedidia/revisor/kvm"
)

func Boot(m *kvm.Machine, kernel io.ReaderAt, args []string, trace bool) error {
	err := m.LoadKernel(kernel, args)
	if err != nil {
		return err
	}

	var wg sync.WaitGroup

	for i := 0; i < m.NCPU(); i++ {
		log.Println("booting vcpu", i)
		wg.Add(1)
		m.StartVCPU(i, trace, &wg)
	}

	wg.Wait()
	return nil
}
