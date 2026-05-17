#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════════
#  LazyOS Full Installer
#  Arch Linux (UEFI/GPT + ext4 + swap + GRUB) → LazyOS (i3 + dotfiles)
#  Rulează din Arch ISO live environment
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ── Helpers ───────────────────────────────────────────────────────────────────
step() { echo -e "\n${CYAN}[$1]${NC} $2"; }
info() { echo -e "${YELLOW}  →${NC} $1"; }
ok()   { echo -e "${GREEN}  ✓${NC} $1"; }
die()  { echo -e "\n${RED}[ERROR]${NC} $1"; exit 1; }

# ── Banner ────────────────────────────────────────────────────────────────────
clear
echo -e "${CYAN}"
cat << "EOF"
    __                      ____  _____
   / /   ____ _____  __  __/ __ \/ ___/
  / /   / __ `/_  / / / / / / / /\__ \ 
 / /___/ /_/ / / /_/ /_/ / /_/ /___/ / 
/_____/\__,_/ /___/\__, /\____//____/  
                  /____/               
  Full Installer — Arch Linux + LazyOS
EOF
echo -e "${NC}"

# ── Checks ────────────────────────────────────────────────────────────────────
[ "$EUID" -ne 0 ] && die "Run as root from Arch ISO: bash lazyos-full-install.sh"

ping -c 1 archlinux.org &>/dev/null || die "No internet connection!"

# Verify UEFI mode
[ -d /sys/firmware/efi/efivars ] || die "Not booted in UEFI mode! Check your BIOS settings."

ok "UEFI mode confirmed"
ok "Internet connection confirmed"

# ═══════════════════════════════════════════════════════════════════════════════
#  PART 1 — USER INPUT
# ═══════════════════════════════════════════════════════════════════════════════

echo ""
echo -e "${CYAN}══ Configuration ══════════════════════════════════════════${NC}"
echo ""

# Username
while true; do
  read -rp "  Username: " USERNAME
  [[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]] && break
  echo -e "  ${RED}Invalid username.${NC} Use lowercase letters, numbers, _ or -"
done

# Password
while true; do
  read -rsp "  Password: " PASSWORD
  echo ""
  read -rsp "  Confirm password: " PASSWORD2
  echo ""
  [ "$PASSWORD" = "$PASSWORD2" ] && break
  echo -e "  ${RED}Passwords don't match.${NC} Try again."
done

# Hostname
read -rp "  Hostname [lazyos]: " HOSTNAME
HOSTNAME="${HOSTNAME:-lazyos}"

# Timezone
read -rp "  Timezone [Europe/Bucharest]: " TIMEZONE
TIMEZONE="${TIMEZONE:-Europe/Bucharest}"

# Locale
read -rp "  Locale [en_US.UTF-8]: " LOCALE
LOCALE="${LOCALE:-en_US.UTF-8}"

# Swap size
read -rp "  Swap size in GB [4]: " SWAP_GB
SWAP_GB="${SWAP_GB:-4}"

echo ""
echo -e "${CYAN}══ Disk Selection ══════════════════════════════════════════${NC}"
echo ""

# Show available disks
lsblk -d -o NAME,SIZE,TYPE,MODEL | grep disk
echo ""

while true; do
  read -rp "  Select disk (e.g. sda, nvme0n1): " DISK_NAME
  DISK="/dev/${DISK_NAME}"
  [ -b "$DISK" ] && break
  echo -e "  ${RED}Disk not found:${NC} $DISK"
done

# ── Confirm ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}══ Summary ═════════════════════════════════════════════════${NC}"
echo -e "  Disk      : ${RED}$DISK${NC} ${RED}(ALL DATA WILL BE ERASED)${NC}"
echo -e "  User      : $USERNAME"
echo -e "  Hostname  : $HOSTNAME"
echo -e "  Timezone  : $TIMEZONE"
echo -e "  Locale    : $LOCALE"
echo -e "  Swap      : ${SWAP_GB}GB"
echo -e "  Filesystem: ext4"
echo -e "  Bootloader: GRUB (UEFI)"
echo ""
read -rp "  Proceed? Type YES to confirm: " CONFIRM
[ "$CONFIRM" = "YES" ] || die "Aborted by user."

# ═══════════════════════════════════════════════════════════════════════════════
#  PART 2 — DISK SETUP
# ═══════════════════════════════════════════════════════════════════════════════

step "1/8" "Partitioning disk: $DISK"

# Wipe disk
wipefs -af "$DISK"
sgdisk --zap-all "$DISK"

# Create GPT partitions:
#   1 — EFI   512MB
#   2 — swap  ${SWAP_GB}GB
#   3 — root  remainder
sgdisk -n 1:0:+512M  -t 1:ef00 -c 1:"EFI"  "$DISK"
sgdisk -n 2:0:+${SWAP_GB}G -t 2:8200 -c 2:"swap" "$DISK"
sgdisk -n 3:0:0      -t 3:8300 -c 3:"root" "$DISK"

# Resolve partition names (handles nvme0n1p1 vs sda1)
if [[ "$DISK" == *"nvme"* ]] || [[ "$DISK" == *"mmcblk"* ]]; then
  EFI_PART="${DISK}p1"
  SWAP_PART="${DISK}p2"
  ROOT_PART="${DISK}p3"
else
  EFI_PART="${DISK}1"
  SWAP_PART="${DISK}2"
  ROOT_PART="${DISK}3"
fi

ok "Partitions created: EFI=$EFI_PART  SWAP=$SWAP_PART  ROOT=$ROOT_PART"

step "2/8" "Formatting partitions..."

mkfs.fat -F32 "$EFI_PART"
ok "EFI formatted (FAT32)"

mkswap "$SWAP_PART"
swapon "$SWAP_PART"
ok "Swap formatted and enabled"

mkfs.ext4 -F "$ROOT_PART"
ok "Root formatted (ext4)"

step "3/8" "Mounting filesystems..."

mount "$ROOT_PART" /mnt
mkdir -p /mnt/boot/efi
mount "$EFI_PART" /mnt/boot/efi

ok "Filesystems mounted"

# ═══════════════════════════════════════════════════════════════════════════════
#  PART 3 — BASE INSTALL
# ═══════════════════════════════════════════════════════════════════════════════

step "4/8" "Installing Arch base system (pacstrap)..."

pacstrap -K /mnt \
  base base-devel linux linux-firmware \
  networkmanager grub efibootmgr \
  git curl wget sudo zsh \
  nano vim || die "pacstrap failed"

ok "Base system installed"

step "5/8" "Generating fstab..."

genfstab -U /mnt >> /mnt/etc/fstab
ok "fstab generated"

# ═══════════════════════════════════════════════════════════════════════════════
#  PART 4 — CHROOT CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

step "6/8" "Configuring system (chroot)..."

arch-chroot /mnt /bin/bash << CHROOT
set -euo pipefail

# Timezone
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
hwclock --systohc

# Locale
sed -i "s/^#${LOCALE}/${LOCALE}/" /etc/locale.gen
locale-gen
echo "LANG=${LOCALE}" > /etc/locale.conf

# Hostname
echo "${HOSTNAME}" > /etc/hostname
cat >> /etc/hosts << EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
EOF

# Root password
echo "root:${PASSWORD}" | chpasswd

# Create user
useradd -m -G wheel,audio,video,storage,optical -s /bin/zsh "${USERNAME}"
echo "${USERNAME}:${PASSWORD}" | chpasswd

# Enable sudo for wheel group
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Enable NetworkManager
systemctl enable NetworkManager

# GRUB (UEFI)
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=LazyOS
grub-mkconfig -o /boot/grub/grub.cfg

echo "Chroot configuration done."
CHROOT

ok "System configured"

# ═══════════════════════════════════════════════════════════════════════════════
#  PART 5 — LAZYOS INSTALL (inside chroot as the new user)
# ═══════════════════════════════════════════════════════════════════════════════

step "7/8" "Installing LazyOS (i3 + tools + dotfiles)..."

arch-chroot /mnt /bin/bash << CHROOT
set -euo pipefail

BUILD_USER="${USERNAME}"
USER_HOME="/home/${USERNAME}"

# ── Core packages ─────────────────────────────────────────────────────────────
pacman -S --noconfirm --needed \
  i3-wm polybar rofi alacritty picom feh dunst \
  neovim ranger btop fastfetch \
  xorg xorg-xinit lightdm lightdm-gtk-greeter || exit 1

# Enable display manager
systemctl enable lightdm

# ── yay (AUR helper) ──────────────────────────────────────────────────────────
BUILD_DIR="/tmp/yay-build"
rm -rf "\$BUILD_DIR"
mkdir -p "\$BUILD_DIR"
chown "\$BUILD_USER":"\$BUILD_USER" "\$BUILD_DIR"

sudo -u "\$BUILD_USER" git clone https://aur.archlinux.org/yay.git "\$BUILD_DIR"
sudo -u "\$BUILD_USER" bash -c "cd '\$BUILD_DIR' && makepkg -si --noconfirm --needed"
rm -rf "\$BUILD_DIR"

command -v yay &>/dev/null || { echo "yay not found!"; exit 1; }

# ── AUR packages ──────────────────────────────────────────────────────────────
sudo -u "\$BUILD_USER" yay -S --noconfirm --needed \
  zen-browser-bin i3lock-color

# ── Dotfiles ──────────────────────────────────────────────────────────────────
DOTFILES_DIR="\$USER_HOME/lazyos-dotfiles"
DOTFILES_REPO="https://github.com/Halespider396/lazyos-dotfiles.git"
CONFIG_DIR="\$USER_HOME/.config"

sudo -u "\$BUILD_USER" git clone "\$DOTFILES_REPO" "\$DOTFILES_DIR"

mkdir -p "\$CONFIG_DIR"

for dir in i3 alacritty dunst polybar; do
  cp -r "\${DOTFILES_DIR}/\${dir}/" "\${CONFIG_DIR}/"
done
cp "\${DOTFILES_DIR}/picom.conf" "\${CONFIG_DIR}/picom.conf"

chown -R "\$BUILD_USER":"\$BUILD_USER" "\$CONFIG_DIR" "\$DOTFILES_DIR"

echo "LazyOS install done."
CHROOT

ok "LazyOS installed"

# ═══════════════════════════════════════════════════════════════════════════════
#  PART 6 — DONE
# ═══════════════════════════════════════════════════════════════════════════════

step "8/8" "Cleaning up..."

umount -R /mnt
swapoff "$SWAP_PART"

ok "Unmounted all filesystems"

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   LazyOS installation complete! 🎉               ║${NC}"
echo -e "${GREEN}║                                                  ║${NC}"
echo -e "${GREEN}║   Remove the USB and reboot:                     ║${NC}"
echo -e "${GREEN}║     reboot                                       ║${NC}"
echo -e "${GREEN}║                                                  ║${NC}"
echo -e "${GREEN}║   Log in as: ${CYAN}${USERNAME}${GREEN}                            ║${NC}"
echo -e "${GREEN}║   Select i3 from LightDM and enjoy!             ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
