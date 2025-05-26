# Alpine-on-Banana-Pi-M1
Learn how to install and configure Alpine Linux on a Banana Pi M1 single-board computer. This step-by-step guide covers everything from preparing the bootable media to initial system setup, with tips for optimizing Alpine Linux for lightweight and efficient performance on ARM-based hardware. Perfect for minimalists and DIY enthusiasts.

Download
```
#!/bin/sh

BASE_URL="https://dl-cdn.alpinelinux.org/alpine"

# 1. Recupera tutte le directory vX.Y, ordinale in modo decrescente
branches=$(wget -qO- https://dl-cdn.alpinelinux.org/alpine/ | grep -oE 'v[0-9]+\.[0-9]+/' | sed 's#/##' | awk '!seen[$0]++' | sort -Vr)

# 2. Cicla sui rami dal più recente e cerca un tarball valido
for branch in $branches; do
    RELEASE_URL="$BASE_URL/$branch/releases/armv7/"

    echo "🔍 Controllo in: $RELEASE_URL"

    # Cerca il tarball alpine-uboot-*.tar.gz in quella release
    uboot_file=$(wget -qO- "$RELEASE_URL" | grep -oE 'alpine-uboot-[0-9]+\.[0-9]+\.[0-9]+-armv7\.tar\.gz' | sort -V | tail -n1)

    if [ -n "$uboot_file" ]; then
        echo "✅ Trovato: $uboot_file"
        echo "⬇️ Download in corso da: $RELEASE_URL$uboot_file"
        wget -c "$RELEASE_URL$uboot_file"
        exit 0
    fi
done

echo "❌ Nessuna release alpine-uboot trovata in nessun ramo disponibile."
exit 1
```
Estrazione
```
#!/bin/sh

ARCHIVE=alpine-uboot-*.tar.gz

# Pulisce cartella boot se esiste
rm -rf boot

# Estrae tutto il contenuto dell'archivio
tar xf $ARCHIVE

# Rimuove tutti i dtb tranne quello del Banana Pi
find boot/dtbs-lts -type f -name '*.dtb' ! -name 'sun7i-a20-bananapi.dtb' -delete

# Crea boot/u-boot se non esiste
mkdir -p boot/u-boot

# Trova e sposta il file del bootloader nella root di boot/u-boot/
find u-boot -type f -name 'u-boot-sunxi-with-spl.bin' -exec mv -f {} boot/u-boot/ \;

# Rimuove sottodirectory residue in boot/u-boot
find boot/u-boot -mindepth 1 -type d -exec rm -rf {} +

# Sposta apks e extlinux in boot
mv apks extlinux boot

# Pulisce le cartelle residue
rm -rf efi u-boot boot/grub
```
