SHELL=/bin/bash
.PRECIOUS: packer/alpine/virt/%/packer-alpine packer/alpine/lts/%/packer-alpine

arch?=x86_64
version?=3.15.0
ver:=$(basename $(version))
mirror?=https://mirrors.aliyun.com/alpine

flavor?=virt
format?=raw
# workspace
ws?=.

minirootfs.tar.gz:=alpine-minirootfs-${version}-${arch}.tar.gz
minirootfs_url:=${mirror}/v${ver}/releases/${arch}/$(minirootfs.tar.gz)

# for relative scripts
cwd := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# QEMU Accel
accel_Darwin	:=hvf
accel_Linux		:=kvm
platform		:=$(shell uname -s)
accel			?=$(accel_$(platform))

love:
	@echo No target
	@exit 1

report:
	@echo Alpine $(arch) $(flavor) $(ver)/$(version)
	@echo Repo $(mirror)
	@echo CWD $(cwd)

$(minirootfs.tar.gz):
	curl -LOC- $(minirootfs_url)

rootfs: $(minirootfs.tar.gz)
	mkdir -p rootfs
	tar zxf $(minirootfs.tar.gz) -C rootfs
	#
	cp /etc/apk/repositories rootfs/etc/apk/
	apk --root rootfs add alpine-conf

rootfs.apkvol.tar.gz: rootfs
	chroot rootfs/ lbu pkg rootfs.apkvol.tar.gz
	mv rootfs/rootfs.apkvol.tar.gz .

sysfs: $(cwd)/scripts/sysfs-init.sh $(minirootfs.tar.gz)
	mkdir -p sysfs
	tar zxf $(minirootfs.tar.gz) -C sysfs
	arch=$(arch) $(cwd)/scripts/sysfs-init.sh
	echo Alpine $(arch) $(version) sysfs

sysfs.apkvol.tar.gz: sysfs
	chroot sysfs/ lbu pkg sysfs.apkvol.tar.gz
	mv sysfs/sysfs.apkvol.tar.gz .

# /etc/apk/arch = apk --print-arch
sysfs.%.apkvol.tar.gz:
	rm -rf sysfs sysfs.apkvol.tar.gz
	arch=$* $(MAKE) sysfs.apkvol.tar.gz
	cp sysfs.apkvol.tar.gz sysfs.$*.apkvol.tar.gz
	echo Alpine $(arch) $(version) sysfs.apkvol.tar.gz

artifacts/sysfs.apkvol.tar.gz: sysfs.apkvol.tar.gz
	mkdir -p artifacts
	cp sysfs.apkvol.tar.gz artifacts

artifacts/sysfs.%.apkvol.tar.gz:
	mkdir -p artifacts
	$(MAKE) sysfs.$*.apkvol.tar.gz
	cp sysfs.$*.apkvol.tar.gz $@

mount:
	flavor=$(flavor) $(cwd)/scripts/loopdev-mnt.sh

umount:
	- findmnt /mnt && umount -R /mnt
	- losetup -d /dev/loop0

# alpine-$ARCH-$FLAVOR-$VERSION.img
alpine.img: mount umount
	@echo Alpine $(arch) $(flavor) $(version)

alpine-x86_64-lts-%.img:
	arch=x86_64 flavor=lts version=$* $(MAKE) alpine.img
	cp alpine.img $@
alpine-x86_64-virt-%.img:
	arch=x86_64 flavor=virt version=$* $(MAKE) alpine.img
	cp alpine.img $@

# https://pkgs.alpinelinux.org/packages?name=linux-rpi*&branch=edge
alpine-armhf-rpi.img:
alpine-armhf-rpi2.img:
alpine-armv7-rpi.img:
alpine-armv7-rpi2.img:
alpine-armv7-rpi4.img:
alpine-aarch64-rpi.img:
alpine-aarch64-rpi4.img:

# alpine/x86_64/virt/alpine.img


packer/alpine/virt/%/packer-alpine:
	PACKER_LOG=$(verbose) packer build $(PACKER_FLAGS) \
		-var=dist=packer/alpine/virt/$* \
		-var=flavor=virt -var=format=$* \
		-var=accel=$(accel) \
		scripts/alpine.pkr.hcl
images/virt/alpine.%: packer/alpine/virt/%/packer-alpine
	mkdir -p images/virt
	cp $^ images/virt/alpine.$*

packer/alpine/lts/%/packer-alpine:
	PACKER_LOG=$(verbose) packer build $(PACKER_FLAGS) \
		-var=dist=packer/alpine/lts/$* \
		-var=flavor=lts -var=format=$* \
		-var=accel=$(accel) \
		scripts/alpine.pkr.hcl
images/lts/alpine.%: packer/alpine/lts/%/packer-alpine
	mkdir -p images/lts
	cp $^ $@

builder.qcow2: images/virt/alpine.qcow2

dev: images/virt/alpine.qcow2
	[ ! -e test.qcow2 ] && cp images/virt/alpine.qcow2 test.qcow2 || true
	qemu-system-x86_64 -accel $(accel) -m 4G -smp 2 -net nic -nic user,hostfwd=tcp::2222-:22 -drive if=virtio,file=test.qcow2
	# ssh root@127.0.0.1 -p 2222 -o StrictHostKeyChecking=no

clean:
	-rm -rf packer
distclean: clean
	-rm -rf images
