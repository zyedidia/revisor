#!/bin/sh
cd "$(dirname "$0")/../gokvm"
exec go run . revisor -test \
  -k ../linux/arch/x86/boot/bzImage \
  -i ../guest/initramfs.cpio.gz \
  -m 256M \
  -a 16M \
  -p "console=ttyS0 earlyprintk=serial noapic noacpi rdinit=/bin/init revisor_arena=0x40000000,0x1000000,5,0x3ffff000"
