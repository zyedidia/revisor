package main

import (
	"bytes"
	_ "embed"
	"flag"
	"fmt"
	"io"
	"log"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/zyedidia/revisor"
	"github.com/zyedidia/revisor/kvm"
)

//go:embed rekernel.elf
var rekernel []byte

func parseMem(mem string) (int64, error) {
	num := bytes.Buffer{}
	mod := 'B'
	for _, r := range mem {
		if r >= '0' && r <= '9' {
			num.WriteRune(r)
		} else {
			mod = r
			break
		}
	}
	n, err := strconv.Atoi(num.String())
	if err != nil {
		return 0, err
	}
	switch mod {
	case 'G':
		return int64(n) * 1024 * 1024 * 1024, nil
	case 'M':
		return int64(n) * 1024 * 1024, nil
	case 'K':
		return int64(n) * 1024, nil
	case 'B':
		return int64(n), nil
	default:
		return 0, fmt.Errorf("invalid memory size modifier %c", mod)
	}
}

func main() {
	trace := flag.Bool("trace", false, "show instruction trace")
	kernel := flag.String("kernel", "rekernel", "guest kernel")
	dir := flag.String("dir", ".", "directory to make available to the guest")
	mem := flag.String("mem", "2G", "maximum memory available to the guest")

	flag.Parse()
	args := flag.Args()

	start := time.Now()

	c := revisor.NewContainer(strings.Split(*dir, ":"))
	sz, err := parseMem(*mem)
	if err != nil {
		log.Fatal(err)
	}
	m, err := kvm.NewMachine("/dev/kvm", 1, sz, c)
	if err != nil {
		log.Fatal(err)
	}

	var kdata io.ReaderAt

	switch *kernel {
	case "rekernel":
		kdata = bytes.NewReader(rekernel)
	default:
		kfile, err := os.Open(*kernel)
		if err != nil {
			log.Fatal(err)
		}
		defer kfile.Close()
		kdata = kfile
	}

	err = revisor.Boot(m, kdata, args, *trace)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println("time:", time.Since(start))
}
