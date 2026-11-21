
#!/bin/bash
set -Eeuo pipefail

ROOT=/mnt
BOOT=/mnt/boot
LOG=/tmp/arch-repair.log

exec > >(tee -a "$LOG") 2>&1

trap 'echo "ERROR: Repair stopped at line $LINENO. Log: $LOG"' ERR

echo "=== ARCH BOOT REPAIR ==="

# Verify environment
[[ $EUID -eq 0 ]] || { echo "Run as root"; exit 1; }
mountpoint -q "$ROOT" || { echo "/mnt is not mounted"; exit 1; }
mountpoint -q "$BOOT" || { echo "/mnt/boot is not mounted"; exit 1; }
[[ -f "$ROOT/etc/arch-release" ]] || {
    echo "Arch installation not found"
    exit 1
}

FSTYPE=$(findmnt -n -o FSTYPE "$BOOT")
[[ "$FSTYPE" == "vfat" ]] || {
    echo "EFI partition must be FAT32"
    exit 1
}

echo "[1/6] Checking EFI boot mode..."

if [[ ! -d /sys/firmware/efi ]]; then
    echo "ERROR: Live USB was not booted in UEFI mode."
    exit 1
fi

echo "[2/6] Installing required packages..."

arch-chroot "$ROOT" pacman -S --needed --noconfirm \
    linux linux-firmware mkinitcpio grub efibootmgr

echo "[3/6] Checking kernel image..."

if [[ ! -s "$BOOT/vmlinuz-linux" ]]; then
    echo "Kernel image missing. Reinstalling kernel..."
    arch-chroot "$ROOT" pacman -S --noconfirm linux
fi

arch-chroot "$ROOT" bash -c '
    [[ -s /boot/vmlinuz-linux ]] || {
        echo "Kernel image still missing"
        exit 1
    }
'

echo "[4/6] Generating initramfs..."

arch-chroot "$ROOT" mkinitcpio -P

echo "[5/6] Installing GRUB..."

arch-chroot "$ROOT" grub-install \
    --target=x86_64-efi \
    --efi-directory=/boot \
    --bootloader-id=Arch \
    --removable

echo "[6/6] Generating GRUB configuration..."

arch-chroot "$ROOT" grub-mkconfig \
    -o /boot/grub/grub.cfg

echo
echo "=== VERIFYING BOOT FILES ==="

ls -lh "$BOOT/EFI/BOOT"
ls -lh "$BOOT/EFI/Arch"
ls -lh "$BOOT/vmlinuz-linux"

echo
echo "=== REPAIR COMPLETED ==="
echo "Log: $LOG"
