package main

import (
	"flag"
	"log"
	"os"

	"github.com/zyedidia/hypertain"
	"github.com/zyedidia/hypertain/kvm"
)

func gb(n int) int {
	return n * 1024 * 1024 * 1024
}

func main() {
	flag.Parse()
	args := flag.Args()

	if len(args) <= 0 {
		log.Fatal("no input")
	}

	container := hypertain.NewContainer()

	m, err := kvm.NewMachine("/dev/kvm", 1, gb(16), container)
	if err != nil {
		log.Fatal(err)
	}

	kernel, err := os.Open(args[0])
	if err != nil {
		log.Fatal(err)
	}
	defer kernel.Close()

	err = hypertain.Boot(m, kernel, "")
	if err != nil {
		log.Fatal(err)
	}
}
