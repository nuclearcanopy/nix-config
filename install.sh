#!/usr/bin/env bash
set -e

# Kuraokami NixOS Install Script
# Run this from the NixOS live ISO after cloning the repo

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${GREEN}=== Kuraokami NixOS Install ===${NC}\n"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Run this script with sudo${NC}"
  exit 1
fi

# Get username from flake.nix
USERNAME=$(grep 'username = ' flake.nix | head -1 | sed 's/.*username = "\([^"]*\)".*/\1/')
echo -e "Username: ${GREEN}${USERNAME}${NC}\n"

# Age identity (provided by user)
echo -e "${CYAN}=== Age identity ===${NC}\n"
read -p "Place /etc/age/key.txt yourself? [Y/n] " PLACE_SELF
if [ "$PLACE_SELF" = "n" ] || [ "$PLACE_SELF" = "N" ]; then
  echo -e "${YELLOW}Paste your age identity key. End with Ctrl-D:${NC}"
  mkdir -p /etc/age
  cat > /etc/age/key.txt
  chmod 600 /etc/age/key.txt
else
  echo -e "Expected at: ${GREEN}/etc/age/key.txt${NC}"
fi

if [ ! -f "/etc/age/key.txt" ]; then
  echo -e "${RED}Missing /etc/age/key.txt. Add it, then re-run.${NC}"
  exit 1
fi

# Confirm disk wipe
echo -e "${YELLOW}WARNING: This will WIPE /dev/nvme0n1${NC}"
echo "Make sure this is the correct drive!"
echo ""
lsblk /dev/nvme0n1
echo ""
read -p "Type 'yes' to continue: " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "Aborted."
  exit 1
fi

# Step 1: Partition and format with disko
echo -e "\n${GREEN}[1/4] Partitioning with disko...${NC}"
nix --experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko ./hardware/disko.nix

# Step 2: Install NixOS
echo -e "\n${GREEN}[2/4] Installing NixOS...${NC}"
nixos-install --flake .#kuraokami --no-root-password

# Step 3: Copy repo to new system
echo -e "\n${GREEN}[3/4] Copying config to new system...${NC}"
DEST="/mnt/home/${USERNAME}/nix-config"
mkdir -p "$DEST"
cp -r . "$DEST"
chown -R 1000:users "/mnt/home/${USERNAME}"

# Step 4: Done
echo -e "\n${GREEN}[4/4] Installation complete!${NC}"
echo ""
echo "Your config is at: ~/nix-config"
echo ""
echo "Next steps:"
echo "  1. Reboot into your new system"
echo "  2. Log in as ${USERNAME}"
echo ""
read -p "Reboot now? [y/N] " REBOOT
if [ "$REBOOT" = "y" ] || [ "$REBOOT" = "Y" ]; then
  reboot
fi
