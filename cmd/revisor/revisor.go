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

	c := revisor.NewContainer()
	m, err := kvm.NewMachine("/dev/kvm", 1, gb(2), c)
	if err != nil {
		log.Fatal(err)
	}

	kernel, err := os.Open(args[0])
	if err != nil {
		log.Fatal(err)
	}
	defer kernel.Close()

	err = revisor.Boot(m, kernel, args[1:], *trace)
	if err != nil {
		log.Fatal(err)
	}
}
