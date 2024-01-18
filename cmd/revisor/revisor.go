package main

import (
	"bytes"
	_ "embed"
	"flag"
	"fmt"
	"io"
	"log"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/zyedidia/revisor"
	"github.com/zyedidia/revisor/kvm"
)

//go:embed rekernel.elf
var rekernel []byte

func registerSignals(c *revisor.Container, m *kvm.Machine) {
	sigc := make(chan os.Signal, 1)

	signal.Notify(sigc,
		syscall.SIGABRT,
		syscall.SIGBUS,
		syscall.SIGCLD,
		syscall.SIGCONT,
		syscall.SIGFPE,
		syscall.SIGHUP,
		syscall.SIGINT,
		syscall.SIGIO,
		syscall.SIGIOT,
		syscall.SIGPIPE,
		syscall.SIGPOLL,
		syscall.SIGPWR,
		syscall.SIGQUIT,
		syscall.SIGSEGV,
		syscall.SIGSTKFLT,
		syscall.SIGSYS,
		syscall.SIGTERM,
		syscall.SIGTRAP,
		syscall.SIGTSTP,
		syscall.SIGTTIN,
		syscall.SIGTTOU,
		syscall.SIGUNUSED,
		// syscall.SIGURG,
		syscall.SIGUSR1,
		syscall.SIGUSR2,
		syscall.SIGWINCH,
	)

	go func() {
		for {
			s := <-sigc
			err := c.Signal(m, s)
			if err != nil {
				fmt.Fprintf(os.Stderr, "error handling signal %v: %v", s, err)
			}
		}
	}()
}

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

	registerSignals(c, m)

	err = revisor.Boot(m, kdata, args, *trace)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println("time:", time.Since(start))
}
