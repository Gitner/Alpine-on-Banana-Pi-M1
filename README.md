# Alpine-on-Banana-Pi-M1
Learn how to install and configure Alpine Linux on a Banana Pi M1 single-board computer. This step-by-step guide covers everything from preparing the bootable media to initial system setup, with tips for optimizing Alpine Linux for lightweight and efficient performance on ARM-based hardware. Perfect for minimalists and DIY enthusiasts.

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
