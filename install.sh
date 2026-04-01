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

# Generate secrets.nix if it doesn't exist
if [ ! -f "secrets.nix" ]; then
  echo -e "${CYAN}=== Setting up secrets ===${NC}\n"

  # User password
  echo -e "${YELLOW}Set your login password:${NC}"
  while true; do
    read -s -p "Password: " USER_PASS
    echo
    read -s -p "Confirm: " USER_PASS_CONFIRM
    echo
    if [ "$USER_PASS" = "$USER_PASS_CONFIRM" ]; then
      break
    fi
    echo -e "${RED}Passwords don't match, try again${NC}"
  done
  HASHED_PASS=$(echo "$USER_PASS" | mkpasswd -m sha-512 -s)

  # NAS config (optional)
  echo ""
  read -p "Configure NAS mount? [y/N] " SETUP_NAS
  if [ "$SETUP_NAS" = "y" ] || [ "$SETUP_NAS" = "Y" ]; then
    read -p "NAS IP address: " NAS_IP
    read -p "NAS share name: " NAS_SHARE
    read -p "NAS username: " NAS_USER
    read -s -p "NAS password: " NAS_PASS
    echo
  else
    NAS_IP="0.0.0.0"
    NAS_SHARE="disabled"
    NAS_USER="disabled"
    NAS_PASS="disabled"
  fi

  # Write secrets.nix
  cat > secrets.nix <<EOF
{
  nas = {
    ip = "${NAS_IP}";
    share = "${NAS_SHARE}";
    username = "${NAS_USER}";
    password = "${NAS_PASS}";
  };

  user = {
    hashedPassword = "${HASHED_PASS}";
  };
}
EOF

  echo -e "\n${GREEN}secrets.nix created${NC}\n"
else
  echo -e "Using existing secrets.nix\n"
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
nix --experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko --flake .#kuraokami

# Step 2: Install NixOS
echo -e "\n${GREEN}[2/4] Installing NixOS...${NC}"
nixos-install --flake .#kuraokami --impure --no-root-password

# Step 3: Copy repo to new system
echo -e "\n${GREEN}[3/4] Copying config to new system...${NC}"
DEST="/mnt/home/${USERNAME}/nix-config"
mkdir -p "$DEST"
cp -r . "$DEST"
cp secrets.nix "$DEST/secrets.nix"
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
