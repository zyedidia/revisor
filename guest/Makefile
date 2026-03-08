LINUX_DIR := ../linux
GOKVM_DIR := ../gokvm

MUSL_GCC := musl-gcc

.PHONY: all init initramfs kernel run clean

all: initramfs kernel

# Build static init binary
init: init.c
	$(MUSL_GCC) -static -Os -o $@ $<
	strip $@

# Build initramfs (cpio archive)
initramfs: initramfs.cpio.gz

initramfs.cpio.gz: init
	rm -rf _initramfs
	mkdir -p _initramfs/bin _initramfs/proc _initramfs/sys _initramfs/dev
	cp init _initramfs/bin/init
	(cd _initramfs && find . | cpio -o -H newc --quiet | gzip) > $@
	rm -rf _initramfs

# Build minimal kernel
kernel: $(LINUX_DIR)/arch/x86/boot/bzImage

$(LINUX_DIR)/arch/x86/boot/bzImage: kernel.config
	$(MAKE) -C $(LINUX_DIR) ARCH=x86_64 allnoconfig
	cd $(LINUX_DIR) && scripts/kconfig/merge_config.sh -m .config $(CURDIR)/kernel.config
	$(MAKE) -C $(LINUX_DIR) ARCH=x86_64 olddefconfig
	$(MAKE) -C $(LINUX_DIR) ARCH=x86_64 -j$$(nproc) bzImage

# Boot the VM with gokvm
run: initramfs kernel
	cd $(GOKVM_DIR) && go run . boot \
		-k $(CURDIR)/../linux/arch/x86/boot/bzImage \
		-i $(CURDIR)/initramfs.cpio.gz \
		-m 128M \
		-p "console=ttyS0 earlyprintk=serial noapic noacpi rdinit=/bin/init"

clean:
	rm -f init initramfs.cpio.gz
	rm -rf _initramfs
