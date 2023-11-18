package main

import (
	"flag"
	"log"
	"os"

	"github.com/zyedidia/revisor"
	"github.com/zyedidia/revisor/kvm"
)

func gb(n int) int {
	return n * 1024 * 1024 * 1024
}

func main() {
	trace := flag.Bool("trace", false, "show instruction trace")

	flag.Parse()
	args := flag.Args()

	if len(args) <= 0 {
		log.Fatal("no input")
	}

	container := revisor.NewContainer()

	m, err := kvm.NewMachine("/dev/kvm", 1, gb(16), container)
	if err != nil {
		log.Fatal(err)
	}

	kernel, err := os.Open(args[0])
	if err != nil {
		log.Fatal(err)
	}
	defer kernel.Close()

	err = revisor.Boot(m, kernel, "", *trace)
	if err != nil {
		log.Fatal(err)
	}
}
