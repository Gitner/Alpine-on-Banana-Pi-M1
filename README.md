# Alpine-on-Banana-Pi-M1
Learn how to install and configure Alpine Linux on a Banana Pi M1 single-board computer. This step-by-step guide covers everything from preparing the bootable media to initial system setup, with tips for optimizing Alpine Linux for lightweight and efficient performance on ARM-based hardware. Perfect for minimalists and DIY enthusiasts.

format_and_mount_sd.sh
```
#!/bin/bash

set -e

# Lista dei comandi richiesti
REQUIRED_CMDS=("lsblk" "parted" "mkfs.vfat" "mount" "umount" "grep" "sudo" "awk")

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

# Controlla e smonta eventuali partizioni già presenti e montate
for part in $(lsblk -ln -o NAME "$DEV" | tail -n +2); do
  PART_PATH="/dev/$part"
  if mountpoint -q "$(lsblk -ln -o MOUNTPOINT "$PART_PATH" | grep -v '^$')"; then
    echo "La partizione $PART_PATH è montata, eseguo umount..."
    sudo umount "$PART_PATH"
  fi
done

for part in $(lsblk -ln -o NAME "$DEV" | tail -n +2); do
  if mountpoint -q "/dev/$part"; then
    sudo umount "/dev/$part"
  fi
done

sudo parted -s "$DEV" mklabel msdos
sudo parted -s "$DEV" mkpart primary fat32 2048s 100%

PART="${DEV}1"
if [ ! -b "$PART" ]; then
  PART="${DEV}p1"
fi

sleep 2

sudo parted -s "$DEV" set 1 boot on
sudo mkfs.vfat -F 32 "$PART"

MOUNT_POINT="/mnt/sd_$(date +%s)"
sudo mkdir -p "$MOUNT_POINT"
sudo mount "$PART" "$MOUNT_POINT"

echo "La partizione è stata montata su $MOUNT_POINT"
echo "Cambiando directory su $MOUNT_POINT..."
cd "$MOUNT_POINT"
exec bash
```
setup_alpine_bpi.sh
```
#!/bin/sh

set -e

BASE_URL="https://dl-cdn.alpinelinux.org/alpine"

# Step 1: Trova l'ultima release disponibile per armv7
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

# Step 2: Estrazione e preparazione dei file
echo "📦 Estrazione dei file..."
ARCHIVE="$uboot_file"

# Pulisce la cartella boot se esiste
rm -rf boot

# Estrae tutto il contenuto dell'archivio
tar xf "$ARCHIVE"

# Mantiene solo il dtb del Banana Pi
find boot/dtbs-lts -type f -name '*.dtb' ! -name 'sun7i-a20-bananapi.dtb' -delete

# Crea boot/u-boot se non esiste
mkdir -p boot/u-boot

# Trova e sposta il bootloader nella root di boot/u-boot/
find u-boot -type f -name 'u-boot-sunxi-with-spl.bin' -exec mv -f {} boot/u-boot/ \;

# Rimuove sotto-directory residue in boot/u-boot
find boot/u-boot -mindepth 1 -type d -exec rm -rf {} +

# Sposta extlinux in boot
[ -d extlinux ] && mv extlinux boot

# Pulisce cartelle residue
rm -rf efi u-boot boot/grub

echo "✅ Operazione completata."
```
