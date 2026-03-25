#!/bin/bash

# Colors
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${CYAN}"
cat <<"EOF"
# Colors
CYAN='\033[0;36m'
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
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root: curl URL | sudo bash -s -- YouyName"
  exit 1
fi
echo -e "${NC}"
echo -e "${CYAN}Welcome to LazyOS Installer!${NC}"
echo ""
echo "Press ENTER to continue..."
read
echo ""
echo "Enter your username:"
USERNAME=${1:-"user"}
echo "Hello $USERNAME! Installing LazyOS..."

echo ""
echo -e "${CYAN}[LazyOS]${NC} Starting installation..."
sleep 1

echo -e "${CYAN}[1/5]${NC} Updating system..."
sudo pacman -Syu --noconfirm

echo -e "${CYAN}[2/5]${NC} Installing core packages..."
sudo pacman -S --noconfirm i3-wm polybar rofi alacritty picom feh dunst

echo -e "${CYAN}[3/5]${NC} Installing tools..."
pacman -S --noconfirm neovim ranger btop fastfetch zsh git

echo -e "${CYAN}[3.5/5]${NC} Installing yay..."
cd /tmp
git clone https://aur.archlinux.org/yay.git
cd yay
cd yay
makepkg -si --noconfirm
cd ~

echo -e "${CYAN}[4/5]${NC} Installing AUR packages..."
yay -S --noconfirm zen-browser-bin i3lock-color

echo -e "${CYAN}[5/5]${NC} Copyping dotfiles..."
git clone https://github.com/Halespider396/lazyos-dotfiles.git ~/lazyos-dotfiles
cp -r ~/lazyos-dotfiles/i3/ ~/.config/
cp -r ~/lazyos-dotfiles/alacritty/ ~/.config/
cp -r ~/lazyos-dotfiles/dunst/ ~/.config/
cp -r ~/lazyos-dotfiles/polybar/ ~/.config/
cp -r ~/lazyos-dotfiles/picom.conf/ ~/.config/
echo -e "${CYAN}[LazyOS]${NC} installation complete! Welcome $USERNAME"
