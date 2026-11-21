#!/bin/sh
# Runs inside an alpine container (see build-iso.sh). Inputs in /work:
#   alpine.iso, payload/ (compose bundle + images), overlay/ (live installer files)
# Output: /work/out.iso
set -eu
W=/work
apk add -q xorriso abuild >/dev/null

# 1. offline package repo for the installer (docker, kernel, bootloaders) — signed with a throwaway key
mkdir -p $W/dv-apks/x86_64
apk fetch -q -R -o $W/dv-apks/x86_64 \
	docker docker-openrc containerd-openrc docker-cli-compose linux-virt mkinitfs syslinux grub grub-efi efibootmgr dosfstools mtools \
	e2fsprogs sfdisk chrony tzdata iptables ip6tables
export PACKAGER="docs-vault build <build@docs-vault.invalid>"
abuild-keygen -a -n -q >/dev/null 2>&1 || abuild-keygen -a -n
. ~/.abuild/abuild.conf
KEYNAME=$(basename "$PACKAGER_PRIVKEY")
(cd $W/dv-apks/x86_64 && apk index -q -o APKINDEX.tar.gz --rewrite-arch x86_64 *.apk && abuild-sign -q APKINDEX.tar.gz)

# 2. apkovl: configuration overlay the live system boots with
OVL=$W/ovl
rm -rf $OVL; cp -a $W/overlay $OVL
mkdir -p $OVL/etc/apk/keys $OVL/etc/runlevels/sysinit $OVL/etc/runlevels/boot $OVL/etc/runlevels/default $OVL/etc/runlevels/shutdown
cp "$PACKAGER_PRIVKEY.pub" "$OVL/etc/apk/keys/$KEYNAME.pub"
for s in devfs dmesg mdev hwdrivers modloop; do ln -sf /etc/init.d/$s $OVL/etc/runlevels/sysinit/$s; done
for s in hwclock modules sysctl hostname bootmisc syslog networking; do ln -sf /etc/init.d/$s $OVL/etc/runlevels/boot/$s; done
for s in mount-ro killprocs savecache; do ln -sf /etc/init.d/$s $OVL/etc/runlevels/shutdown/$s; done
(cd $OVL && tar -czf $W/docs-vault.apkovl.tar.gz --owner=0 --group=0 *)

# 3. remaster the Alpine ISO (keeps its BIOS + UEFI boot setup)
rm -f $W/out.iso
xorriso -indev $W/alpine.iso -outdev $W/out.iso \
	-map $W/dv-apks /dv-apks \
	-map $W/payload /docs-vault \
	-map $W/docs-vault.apkovl.tar.gz /docs-vault.apkovl.tar.gz \
	-boot_image any replay 2>&1 | grep -iE 'error|sorry|failure' || true
ls -la $W/out.iso
