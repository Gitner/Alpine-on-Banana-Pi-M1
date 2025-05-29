# Alpine on Banana Pi M1
How to install and configure Alpine Linux on a **Banana Pi M1** single-board computer. This step-by-step script covers almost everything from preparing the bootable media to initial system setup (setup-alpine), perfect for minimalists and DIY enthusiasts.

## Alpine Linux SD Card Preparation Script for Banana Pi (armv7)

This Bash script automates the process of formatting a storage device (like an SD card), downloading the latest Alpine U-Boot release, extracting the required files, and flashing the U-Boot bootloader for devices like the Banana Pi M1 (sun7i-a20).
Partition and Format
```
dd if=/dev/zero of="$DEV" ...
parted -s "$DEV" ...
mkfs.vfat ...
```
- Clears the first megabyte of the device (removes partition table)
- Creates a new single FAT32 partition with a boot flag
- Formats the partition using mkfs.vfat

Download the Latest U-Boot Release
```
branches=$(wget -qO- ...)
for branch in $branches; do ...
```
- Queries Alpine’s release tree to find available branches (e.g., v3.21, v3.22)
- For each branch, checks if it contains a alpine-uboot-*.tar.gz file
- Selects the latest release version found and downloads it

Extract and Clean Up U-Boot Archive
```
tar xf "$uboot_file"
...
```
- Extracts the downloaded archive
- Removes all device tree blobs (.dtb) except the one for Banana Pi
- Finds the u-boot-sunxi-with-spl.bin bootloader binary and moves it under boot/u-boot/
- Deletes any remaining subdirectories or files not needed

Move extlinux Configuration (If Present)
```
[ -d extlinux ] && mv extlinux boot
```
- If the archive contains an extlinux directory, it is moved into the boot directory
- Write the Bootloader to the Device
```
dd if=boot/u-boot/u-boot-sunxi-with-spl.bin of="$DEV" bs=1024 seek=8 conv=fsync
```
- If the bootloader binary exists, it is written directly to the SD card starting at offset 8 KiB
- This is the expected location for U-Boot on Allwinner-based Banana Pi boards
