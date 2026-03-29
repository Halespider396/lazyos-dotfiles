#!/bin/bash

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

clear
echo -e "${CYAN}"
cat << "EOF"
    __                      ____  _____
   / /   ____ _____  __  __/ __ \/ ___/
  / /   / __ `/_  / / / / / / / /\__ \ 
 / /___/ /_/ / / /_/ /_/ / /_/ /___/ / 
/_____/\__,_/ /___/\__, /\____//____/  
                  /____/               
EOF
echo -e "${NC}"

# Root check
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root:${NC} curl https://github.com/Halespider396/lazyos-dotfiles/raw/refs/heads/main/lazyos-install.sh | sudo bash -s -- YourName"
  exit 1
fi

echo -e "${CYAN}Welcome to LazyOS Installer!${NC}"
echo ""
echo "Press ENTER to continue..."
read -r

# Username
USERNAME="${1:-user}"
echo ""
echo -e "Hello ${CYAN}${USERNAME}${NC}! Installing LazyOS..."
echo ""

# Helper: step logger
step() {
  echo -e "${CYAN}[$1]${NC} $2"
}

# Error handler
die() {
  echo -e "${RED}[ERROR]${NC} $1"
  exit 1
}

step "LazyOS" "Starting installation..."
sleep 1

step "1/5" "Updating system..."
pacman -Syu --noconfirm || die "System update failed"

step "2/5" "Installing core packages..."
pacman -S --noconfirm \
  i3-wm polybar rofi alacritty picom feh dunst || die "Core package install failed"

step "3/5" "Installing tools..."
pacman -S --noconfirm \
  neovim ranger btop fastfetch zsh \
  git base-devel || die "Tool install failed"

step "3.5/5" "Installing yay (AUR helper)..."
# Build as a non-root user to satisfy makepkg requirements
BUILD_USER="${SUDO_USER:-nobody}"
BUILD_DIR="/tmp/yay-build"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
chown "$BUILD_USER" "$BUILD_DIR"

sudo -u "$BUILD_USER" git clone https://aur.archlinux.org/yay.git "$BUILD_DIR" || die "Failed to clone yay"
cd "$BUILD_DIR" || die "Failed to enter build dir"
sudo -u "$BUILD_USER" makepkg -si --noconfirm || die "yay build failed"
cd ~

step "4/5" "Installing AUR packages..."
sudo -u "$BUILD_USER" yay -S --noconfirm \
  zen-browser-bin i3lock-color || die "AUR package install failed"

step "5/5" "Copying dotfiles..."
DOTFILES_DIR="/home/${SUDO_USER:-$USER}/lazyos-dotfiles"
DOTFILES_REPO="https://github.com/Halespider396/lazyos-dotfiles.git"
CONFIG_DIR="/home/${SUDO_USER:-$USER}/.config"

git clone "$DOTFILES_REPO" "$DOTFILES_DIR" || die "Failed to clone dotfiles"

# picom.conf is a file, not a directory — copy it correctly
for dir in i3 alacritty dunst polybar; do
  cp -r "${DOTFILES_DIR}/${dir}/" "${CONFIG_DIR}/" || die "Failed to copy ${dir} config"
done
cp "${DOTFILES_DIR}/picom.conf" "${CONFIG_DIR}/picom.conf" || die "Failed to copy picom.conf"

# Fix ownership so the actual user owns their config
chown -R "${SUDO_USER:-$USER}:${SUDO_USER:-$USER}" "$CONFIG_DIR" "$DOTFILES_DIR"

echo ""
echo -e "${GREEN}[LazyOS]${NC} Installation complete! Welcome, ${CYAN}${USERNAME}${NC} 🎉"
echo -e "Reboot or log out and select ${CYAN}i3${NC} from your display manager to get started."
