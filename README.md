# Alpine-on-Banana-Pi-M1
Learn how to install and configure Alpine Linux on a Banana Pi M1 single-board computer. This step-by-step guide covers everything from preparing the bootable media to initial system setup, perfect for minimalists and DIY enthusiasts.

Alpine Linux SD Card Preparation Script for Banana Pi (armv7)

This Bash script automates the process of formatting a storage device (like an SD card), downloading the latest Alpine U-Boot release, extracting the required files, and flashing the U-Boot bootloader for devices like the Banana Pi M1 (sun7i-a20).
Partition and Format
```
dd if=/dev/zero of="$DEV" ...
parted -s "$DEV" ...
mkfs.vfat ...
```
Clears the first megabyte of the device (removes partition table).
Creates a new single FAT32 partition with a boot flag.
Formats the partition using mkfs.vfat.

Download the Latest U-Boot Release
```
branches=$(wget -qO- ...)
for branch in $branches; do ...
```
Queries Alpine’s release tree to find available branches (e.g., v3.21, v3.22).
For each branch, checks if it contains a alpine-uboot-*.tar.gz file.
Selects the latest release version found and downloads it.

Extract and Clean Up U-Boot Archive
```
tar xf "$uboot_file"
...
```
Extracts the downloaded archive.
Removes all device tree blobs (.dtb) except the one for Banana Pi.
Finds the u-boot-sunxi-with-spl.bin bootloader binary and moves it under boot/u-boot/.
Deletes any remaining subdirectories or files not needed.

Move extlinux Configuration (If Present)
```
[ -d extlinux ] && mv extlinux boot
```
If the archive contains an extlinux directory, it is moved into the boot directory.
Write the Bootloader to the Device
```
dd if=boot/u-boot/u-boot-sunxi-with-spl.bin of="$DEV" bs=1024 seek=8 conv=fsync
```
If the bootloader binary exists, it is written directly to the SD card starting at offset 8 KiB.
This is the expected location for U-Boot on Allwinner-based Banana Pi boards.

alpine-on-bpi.sh
```
#!/bin/bash

# --- Richiesta automatica dei privilegi root ---
if [ "$EUID" -ne 0 ]; then
  echo "Lo script richiede i privilegi di root. Verrà riavviato con sudo..."
  exec sudo "$0" "$@"
fi

set -e

# --- Controllo prerequisiti ---
REQUIRED_CMDS=("lsblk" "parted" "mkfs.vfat" "mount" "umount" "grep" "awk" "wget" "tar" "find" "dd")
MISSING_CMDS=()
for cmd in "${REQUIRED_CMDS[@]}"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    MISSING_CMDS+=("$cmd")
  fi
done
if [ ${#MISSING_CMDS[@]} -ne 0 ]; then
  echo "I seguenti software sono necessari ma non installati:"
  for cmd in "${MISSING_CMDS[@]}"; do
    echo " - $cmd"
  done
  echo "Installa i pacchetti mancanti e riprova."
  exit 1
fi

# --- Selezione del dispositivo ---
echo "Dispositivi disponibili:"
lsblk -d -o NAME,SIZE,MODEL | grep -E "^sd|^mmcblk"

read -p "Inserisci il nome del dispositivo da formattare (es. sdb o mmcblk0): " DEV
DEV="/dev/$DEV"

if [ ! -b "$DEV" ]; then
  echo "Dispositivo non trovato: $DEV"
  exit 1
fi

echo "ATTENZIONE: Tutti i dati su $DEV saranno cancellati!"
read -p "Vuoi continuare? (scrivi 'SI' per continuare): " CONFIRM
if [ "$CONFIRM" != "SI" ]; then
  echo "Operazione annullata."
  exit 1
fi

# --- Smonta eventuali partizioni montate ---
for part in $(lsblk -ln -o NAME "$DEV" | tail -n +2); do
  PART_PATH="/dev/$part"
  if mountpoint -q "$(lsblk -ln -o MOUNTPOINT "$PART_PATH" | grep -v '^$')"; then
    echo "La partizione $PART_PATH è montata, eseguo umount..."
    umount "$PART_PATH"
  fi
done

# --- Identifica la partizione principale ---
PART="${DEV}1"
if [ ! -b "$PART" ]; then
  PART="${DEV}p1"
fi

# --- Sovrascrivi il primo MB per pulire la tabella partizioni ---
echo "Pulizia del primo megabyte..."
dd if=/dev/zero of="$DEV" bs=1M count=1 conv=fsync

# --- Partiziona e formatta ---
parted -s "$DEV" mklabel msdos
parted -s "$DEV" mkpart primary fat32 2048s 100%

sleep 2

parted -s "$DEV" set 1 boot on
mkfs.vfat -F 32 "$PART"

# --- Monta la partizione ---
MOUNT_POINT="/mnt/sd_$(date +%s)"
mkdir -p "$MOUNT_POINT"
mount "$PART" "$MOUNT_POINT"
echo "La partizione è stata montata su $MOUNT_POINT"
cd "$MOUNT_POINT"

# --- Scarica e prepara i file di Alpine/uboot ---
BASE_URL="https://dl-cdn.alpinelinux.org/alpine"
branches=$(wget -qO- "$BASE_URL/" | grep -oE 'v[0-9]+\.[0-9]+/' | sed 's#/##' | awk '!seen[$0]++' | sort -Vr)
uboot_file=""
for branch in $branches; do
    RELEASE_URL="$BASE_URL/$branch/releases/armv7/"
    echo "🔍 Controllo in: $RELEASE_URL"
    uboot_file=$(wget -qO- "$RELEASE_URL" | grep -oE 'alpine-uboot-[0-9]+\.[0-9]+\.[0-9]+-armv7\.tar\.gz' | sort -V | tail -n1)
    if [ -n "$uboot_file" ]; then
        echo "✅ Trovato: $uboot_file"
        echo "⬇️ Download in corso da: $RELEASE_URL$uboot_file"
        wget -c "$RELEASE_URL$uboot_file"
        break
    fi
done

if [ ! -f "$uboot_file" ]; then
    echo "❌ Nessuna release alpine-uboot trovata in nessun ramo disponibile."
    exit 1
fi

echo "📦 Estrazione dei file..."
tar xf "$uboot_file"

# Mantieni solo il dtb del Banana Pi
find boot/dtbs-lts -type f -name '*.dtb' ! -name 'sun7i-a20-bananapi.dtb' -delete

# Crea boot/u-boot se non esiste e sposta il bootloader
mkdir -p boot/u-boot
find u-boot -type f -name 'u-boot-sunxi-with-spl.bin' -exec mv -f {} boot/u-boot/ \;

# Rimuovi eventuali sotto-directory residue in boot/u-boot
find boot/u-boot -mindepth 1 -type d -exec rm -rf {} +

# Sposta extlinux in boot se presente
[ -d extlinux ] && mv extlinux boot

# --- Scrivi il bootloader sulla SD ---
if [ -f boot/u-boot/u-boot-sunxi-with-spl.bin ]; then
  echo "Scrittura del bootloader sulla SD..."
  dd if=boot/u-boot/u-boot-sunxi-with-spl.bin of="$DEV" bs=1024 seek=8 conv=fsync
  sync
  echo "✅ Bootloader scritto con successo."
else
  echo "❌ File bootloader non trovato: boot/u-boot/u-boot-sunxi-with-spl.bin"
  exit 1
fi

# --- Pulisci cartelle residue ---
rm -rf efi u-boot boot/grub boot/u-boot

echo "Operazione completata. La SD è pronta!"
```
