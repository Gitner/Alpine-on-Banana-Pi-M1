#!/bin/sh
device='/dev/mmcblk1'
boot="${device}p1"
root="${device}p2"
instdir='/bpi'
parted -s $device mktable msdos
parted -s $device unit s -- mkpart primary ext4 2048 1050623
parted -s $device unit s -- mkpart primary ext4 1050624 9439231
parted -s $device -- set 1 boot on
partprobe $device
mkfs.ext4 -L bfs $boot
mkfs.ext4 -L rfs $root
#mkfs.f2fs -l rfs $root
sync
#exit
echo "making dirs and mounting"
rm -rf $instdir
mkdir $instdir
mount $root $instdir
mkdir $instdir/boot
mount $boot $instdir/boot
mkdir $instdir/boot/extlinux
apk -v --root $instdir --arch armv7 --allow-untrusted --initdb \
  -X http://dl-cdn.alpinelinux.org/alpine/v3.14/main \
  -X http://dl-cdn.alpinelinux.org/alpine/v3.14/community \
  add alpine-base alpine-baselayout alpine-conf kmod openrc \
  linux-lts u-boot-leemaker linux-firmware-none util-linux \
  sysfsutils ssl_client ca-certificates-bundle alpine-keys

sync
echo "writing u-boot loader"
dd if=${instdir}/usr/share/u-boot/Bananapi/u-boot-sunxi-with-spl.bin of=$device bs=1024 seek=8

echo "creating extlinux.conf, u-boot setup"
cat > $instdir/boot/extlinux/extlinux.conf<<'EOF'
TIMEOUT 50
PROMPT 1
DEFAULT lts

MENU TITLE Banana PI alpine

LABEL lts
MENU LABEL alpine-lts
KERNEL /vmlinuz-lts
INITRD /initramfs-lts
FDTDIR /dtbs-lts
APPEND modules=sd-mod,usb-storage,ext4,f2fs,sunxi-mmc root=/dev/mmcblk0p2 rw rootwait console=${console}
EOF
sed -i 's/^#ttyS0/ttyS0/' $instdir/etc/inittab
ln -s /etc/init.d/bootmisc $instdir/etc/runlevels/boot/
ln -s /etc/init.d/hostname $instdir/etc/runlevels/boot
ln -s /etc/init.d/modules $instdir/etc/runlevels/boot
ln -s /etc/init.d/sysctl $instdir/etc/runlevels/boot
ln -s /etc/init.d/urandom $instdir/etc/runlevels/boot
ln -s /etc/init.d/devfs $instdir/etc/runlevels/sysinit
ln -s /etc/init.d/hwdrivers $instdir/etc/runlevels/sysinit
ln -s /etc/init.d/mdev $instdir/etc/runlevels/sysinit
ln -s /etc/init.d/modules $instdir/etc/runlevels/sysinit
ln -s /etc/init.d/mount-ro $instdir/etc/runlevels/shutdown
ln -s /etc/init.d/killprocs $instdir/etc/runlevels/shutdown
sync

umount $instdir/boot
umount $instdir
echo
echo "install completed."

exit 0