#!/bin/bash

# Automatically request root privileges
if [ "$EUID" -ne 0 ]; then
  echo "This script requires root privileges. Restarting with sudo..."
  exec sudo "$0" "$@"
fi

set -e

# Check prerequisites
REQUIRED_CMDS=("lsblk" "parted" "mkfs.vfat" "mount" "umount" "grep" "awk" "wget" "tar" "find" "dd")
MISSING_CMDS=()
for cmd in "${REQUIRED_CMDS[@]}"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    MISSING_CMDS+=("$cmd")
  fi
done
if [ ${#MISSING_CMDS[@]} -ne 0 ]; then
  echo "The following required software is missing:"
  for cmd in "${MISSING_CMDS[@]}"; do
    echo " - $cmd"
  done
  echo "Please install the missing packages and try again."
  exit 1
fi

# Device selection
echo "Available devices:"
lsblk -d -o NAME,SIZE,MODEL | grep -E "^sd|^mmcblk"

read -p "Enter the device name to format (e.g. sdb or mmcblk0): " DEV
DEV="/dev/$DEV"

if [ ! -b "$DEV" ]; then
  echo "Device not found: $DEV"
  exit 1
fi

echo "WARNING: All data on $DEV will be erased!"
read -p "Do you want to continue? (type 'YES' to proceed): " CONFIRM
if [ "$CONFIRM" != "YES" ]; then
  echo "Operation cancelled."
  exit 1
fi

# Unmount any mounted partitions
for part in $(lsblk -ln -o NAME "$DEV" | tail -n +2); do
  PART_PATH="/dev/$part"
  if mountpoint -q "$(lsblk -ln -o MOUNTPOINT "$PART_PATH" | grep -v '^$')"; then
    echo "Partition $PART_PATH is mounted, unmounting..."
    umount "$PART_PATH"
  fi
done

# Identify main partition
PART="${DEV}1"
if [ ! -b "$PART" ]; then
  PART="${DEV}p1"
fi

# Overwrite first MB to clean partition table
echo "Wiping the first megabyte..."
dd if=/dev/zero of="$DEV" bs=1M count=1 conv=fsync

# Partition and format
parted -s "$DEV" mklabel msdos
parted -s "$DEV" mkpart primary fat32 2048s 100%

sleep 2

parted -s "$DEV" set 1 boot on
mkfs.vfat -F 32 "$PART"

# Mount the partition
MOUNT_POINT="/mnt/sd_$(date +%s)"
mkdir -p "$MOUNT_POINT"
mount "$PART" "$MOUNT_POINT"
echo "Partition mounted at $MOUNT_POINT"
cd "$MOUNT_POINT"

# Download and prepare Alpine/uboot files
BASE_URL="https://dl-cdn.alpinelinux.org/alpine"
branches=$(wget -qO- "$BASE_URL/" | grep -oE 'v[0-9]+\.[0-9]+/' | sed 's#/##' | awk '!seen[$0]++' | sort -Vr)
uboot_file=""
for branch in $branches; do
    RELEASE_URL="$BASE_URL/$branch/releases/armv7/"
    echo "🔍 Checking: $RELEASE_URL"
    uboot_file=$(wget -qO- "$RELEASE_URL" | grep -oE 'alpine-uboot-[0-9]+\.[0-9]+\.[0-9]+-armv7\.tar\.gz' | sort -V | tail -n1)
    if [ -n "$uboot_file" ]; then
        echo "✅ Found: $uboot_file"
        echo "⬇️ Downloading from: $RELEASE_URL$uboot_file"
        wget -c "$RELEASE_URL$uboot_file"
        break
    fi
done

if [ ! -f "$uboot_file" ]; then
    echo "❌ No alpine-uboot release found in any available branch."
    exit 1
fi

echo "📦 Extracting files..."
tar xf "$uboot_file"

# Keep only Banana Pi dtb
find boot/dtbs-lts -type f -name '*.dtb' ! -name 'sun7i-a20-bananapi.dtb' -delete

# Create boot/u-boot if missing and move bootloader
mkdir -p boot/u-boot
find u-boot -type f -name 'u-boot-sunxi-with-spl.bin' -exec mv -f {} boot/u-boot/ \;

# Remove any leftover subdirectories in boot/u-boot
find boot/u-boot -mindepth 1 -type d -exec rm -rf {} +

# Move extlinux to boot if present
[ -d extlinux ] && mv extlinux boot

# Write bootloader to SD
if [ -f boot/u-boot/u-boot-sunxi-with-spl.bin ]; then
  echo "Writing bootloader to SD..."
  dd if=boot/u-boot/u-boot-sunxi-with-spl.bin of="$DEV" bs=1024 seek=8 conv=fsync
  sync
  echo "✅ Bootloader written successfully."
else
  echo "❌ Bootloader file not found: boot/u-boot/u-boot-sunxi-with-spl.bin"
  exit 1
fi

# Clean up leftover folders
rm -rf efi u-boot boot/grub boot/u-boot "$uboot_file"

# Download headless file to enable ssh
curl -s https://api.github.com/repos/macmpi/alpine-linux-headless-bootstrap/releases/latest \
| grep "headless.apkovl.tar.gz" | cut -d \( -f2 | cut -d \) -f1 | wget -qi -

echo "Done! The SD card is ready."
