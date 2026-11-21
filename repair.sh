
#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/mnt"
EFI="/mnt/boot"
DISK="/dev/sda"
EFI_PART="/dev/sda1"

echo "=== Arch Linux GRUB UEFI Installer ==="

# Verify UEFI
if [[ ! -d /sys/firmware/efi ]]; then
    echo "ERROR: System is not booted in UEFI mode."
    exit 1
fi

# Verify partitions
[[ -d "$ROOT/etc" ]] || {
    echo "ERROR: Arch root is not mounted at /mnt"
    exit 1
}

[[ "$(findmnt -n -o SOURCE "$ROOT")" == "/dev/sda5" ]] || {
    echo "ERROR: Unexpected root partition."
    exit 1
}

[[ "$(findmnt -n -o SOURCE "$EFI")" == "$EFI_PART" ]] || {
    echo "ERROR: EFI partition is not mounted correctly."
    exit 1
}

# Verify FAT filesystem
[[ "$(blkid -s TYPE -o value "$EFI_PART")" == "vfat" ]] || {
    echo "ERROR: EFI partition is not FAT32."
    exit 1
}

# Check free space
FREE_KB=$(df -Pk "$EFI" | awk 'NR==2 {print $4}')

if (( FREE_KB < 15000 )); then
    echo "ERROR: Not enough free space on EFI partition."
    echo "At least 15 MB is required."
    exit 1
fi

# Verify required directories
[[ -d "$ROOT/usr" && -d "$ROOT/boot" ]] || {
    echo "ERROR: Invalid Arch installation."
    exit 1
}

echo "Installing GRUB..."

arch-chroot "$ROOT" pacman -S --needed --noconfirm \
    grub efibootmgr

# Install GRUB
arch-chroot "$ROOT" grub-install \
    --target=x86_64-efi \
    --efi-directory=/boot \
    --bootloader-id=GRUB \
    --no-nvram \
    --recheck

# Generate configuration
arch-chroot "$ROOT" grub-mkconfig \
    -o /boot/grub/grub.cfg

# Verify EFI executable
if [[ ! -s "$EFI/EFI/GRUB/grubx64.efi" ]]; then
    echo "ERROR: GRUB EFI executable was not created."
    exit 1
fi

echo
echo "=== GRUB installation completed ==="
echo "EFI file: /boot/EFI/GRUB/grubx64.efi"
echo "Config:   /boot/grub/grub.cfg"
echo
echo "No partitions were formatted."
echo "No Windows partition
s were modified."
