#!/usr/bin/env bash
set -e

# run from live iso

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

section() {
  echo -e "\n${CYAN}==> ${1}${NC}"
}

ok() {
  echo -e "${GREEN}[ok]${NC} ${1}"
}

warn() {
  echo -e "${YELLOW}[warn]${NC} ${1}"
}

die() {
  echo -e "${RED}[err]${NC} ${1}"
  exit 1
}

ts() {
  date +"%H:%M:%S"
}

now_s() {
  date +%s
}

elapsed() {
  local start=$1
  local end=$2
  local diff=$((end - start))
  local mins=$((diff / 60))
  local secs=$((diff % 60))
  printf "%02dm%02ds" "$mins" "$secs"
}

spinner() {
  local pid=$1
  local msg=$2
  local spin='|/-\'
  local i=0
  printf "%s " "$msg"
  while kill -0 "$pid" 2>/dev/null; do
    i=$(( (i + 1) % 4 ))
    printf "\b%s" "${spin:$i:1}"
    sleep 0.1
  done
  printf "\b"
}

run_step() {
  local msg=$1
  shift
  local start_s
  start_s=$(now_s)
  echo "[$(ts)] START: ${msg}" >> "$LOG"
  "$@" >> "$LOG" 2>&1 & local pid=$!
  spinner "$pid" "$msg"
  wait "$pid"
  local rc=$?
  local end_s
  end_s=$(now_s)
  echo "[$(ts)] END: ${msg} (rc=${rc}, elapsed=$(elapsed "$start_s" "$end_s"))" >> "$LOG"
  return "$rc"
}

progress() {
  local current=$1
  local total=$2
  local width=30
  local filled=$(( current * width / total ))
  local empty=$(( width - filled ))
  printf "\r${GREEN}[%02d/%02d]${NC} [" "$current" "$total"
  printf "%0.s#" $(seq 1 "$filled")
  printf "%0.s-" $(seq 1 "$empty")
  printf "]"
  if [ "$current" -eq "$total" ]; then
    printf "\n"
  fi
}

if [ "$EUID" -ne 0 ]; then
  die "Run this script as root (sudo or doas)"
fi

echo -e "${GREEN}=== NixOS Multi-Host Install ===${NC}\n"

section "Host selection"
echo "Available hosts:"
echo "  1) kuraokami  - Desktop workstation (AMD GPU, Sway, gaming)"
echo "  2) nidhoggr   - Laptop (AMD GPU/CPU, Sway, coding/browsing, power-efficient)"
echo "  3) homeserver - Home server (Docker, Navidrome, etc.)"
echo ""
read -p "Select host [1/2/3]: " HOST_CHOICE

case "$HOST_CHOICE" in
  1|kuraokami)
    HOST="kuraokami"
    DEFAULT_USERNAME="nuclearcanopy"
    DEFAULT_DISK="/dev/nvme0n1"
    ;;
  2|nidhoggr)
    HOST="nidhoggr"
    DEFAULT_USERNAME="nuclearcanopy"
    DEFAULT_DISK="/dev/nvme0n1"
    ;;
  3|homeserver)
    HOST="homeserver"
    DEFAULT_USERNAME="homeserver"
    DEFAULT_DISK="/dev/sda"
    ;;
  *)
    die "Invalid host selection"
    ;;
esac

ok "Selected host: ${HOST}"

LOG="/tmp/${HOST}-install.log"
START_ALL=$(now_s)

echo ""
echo "This installer will:"
echo "  1) Partition and format disk"
echo "  2) Generate hardware config"
echo "  3) Install NixOS (${HOST})"
echo "  4) Copy repo to target system"
echo ""
echo "Log: ${LOG}"
echo ""
echo "[$(ts)] Installer started for ${HOST}" > "$LOG"

section "User"
read -p "Username [${DEFAULT_USERNAME}]: " USERNAME
USERNAME="${USERNAME:-$DEFAULT_USERNAME}"
ok "Username: ${USERNAME}"

section "Age identity"
if [ "$HOST" = "nidhoggr" ]; then
  echo ""
  echo "  nidhoggr uses the same age key as kuraokami by default."
  echo "  If you have your existing key, paste/place it now."
  echo "  If not, generate one: age-keygen -o /etc/age/key.txt"
  echo "  Then add the pubkey (age-keygen -y /etc/age/key.txt) to"
  echo "  secrets/secrets.nix and re-encrypt: cd secrets && agenix -e user-password.age"
  echo ""
fi
read -p "Place /etc/age/key.txt yourself? [Y/n] " PLACE_SELF
if [ "$PLACE_SELF" = "n" ] || [ "$PLACE_SELF" = "N" ]; then
  warn "Paste your age identity key. End with Ctrl-D."
  mkdir -p /etc/age
  cat > /etc/age/key.txt
  chmod 600 /etc/age/key.txt
else
  ok "Expected at: /etc/age/key.txt"
fi

if [ ! -f "/etc/age/key.txt" ]; then
  die "Missing /etc/age/key.txt. Add it, then re-run."
fi

section "Disk selection"
read -p "Disk to install to [${DEFAULT_DISK}]: " DISK
DISK="${DISK:-$DEFAULT_DISK}"
if [ ! -b "$DISK" ]; then
  die "Disk not found: ${DISK}"
fi

warn "This will WIPE ${DISK}"
echo "Make sure this is the correct drive!"
echo ""
lsblk "$DISK"
echo ""
read -p "Type 'yes' to continue: " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "Aborted."
  exit 1
fi

TOTAL_STEPS=5
STEP=1
progress "$STEP" "$TOTAL_STEPS"
section "Partitioning (disko)"
DISKO_PATH="./hosts/${HOST}/disko.nix"
if [ ! -f "$DISKO_PATH" ]; then
  die "Disko config not found: ${DISKO_PATH}"
fi
run_step "Running disko" nix --experimental-features "nix-command flakes" run .#disko -- --mode disko "$DISKO_PATH" --argstr device "$DISK"
ok "Disk partitioned"

STEP=$((STEP + 1))
progress "$STEP" "$TOTAL_STEPS"
section "Generating hardware config"
run_step "nixos-generate-config" nixos-generate-config --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix "./hosts/${HOST}/hardware-configuration.nix"
ok "hardware-configuration.nix updated for ${HOST}"

STEP=$((STEP + 1))
progress "$STEP" "$TOTAL_STEPS"
section "Installing NixOS"
# Copy age key into chroot so agenix can decrypt secrets during activation.
# Without this, hashedPasswordFile points to a non-existent path and you
# can't log in on first boot.
mkdir -p /mnt/etc/age
cp /etc/age/key.txt /mnt/etc/age/key.txt
chmod 600 /mnt/etc/age/key.txt
ok "Age key staged at /mnt/etc/age/key.txt"
run_step "nixos-install" nixos-install --flake ".#${HOST}" --no-root-password
ok "NixOS installed"

STEP=$((STEP + 1))
progress "$STEP" "$TOTAL_STEPS"
section "Copying config to new system"
DEST="/mnt/home/${USERNAME}/nix-config"
mkdir -p "$DEST"
cp -r . "$DEST"
TARGET_UID=$(chroot /mnt id -u "${USERNAME}" 2>/dev/null || true)
TARGET_GID=$(chroot /mnt id -g "${USERNAME}" 2>/dev/null || true)
if [ -n "$TARGET_UID" ] && [ -n "$TARGET_GID" ]; then
  chown -R "${TARGET_UID}:${TARGET_GID}" "/mnt/home/${USERNAME}"
else
  chown -R 1000:users "/mnt/home/${USERNAME}"
fi
ok "Repo copied to target system"

STEP=$((STEP + 1))
progress "$STEP" "$TOTAL_STEPS"
section "Done"
echo -e "${GREEN}Installation complete!${NC}"
END_ALL=$(now_s)
echo "Total time: $(elapsed "$START_ALL" "$END_ALL")"
echo "Log saved to: ${LOG}"
echo ""
echo "Your config is at: ~/nix-config"
echo ""
echo "Next steps:"
echo "  1. Reboot into your new system"
echo "  2. Log in as ${USERNAME}"
if [ "$HOST" = "kuraokami" ]; then
  echo "  3. Run: sudo nixos-rebuild switch --flake ~/nix-config#kuraokami"
elif [ "$HOST" = "nidhoggr" ]; then
  echo "  3. Run: sudo nixos-rebuild switch --flake ~/nix-config#nidhoggr"
  echo ""
  echo "  [nidhoggr] If you used a new age key, remember to:"
  echo "    a) Get pubkey:  age-keygen -y /etc/age/key.txt"
  echo "    b) Update:      secrets/secrets.nix  (replace PLACEHOLDER with pubkey)"
  echo "    c) Re-encrypt:  cd ~/nix-config/secrets && agenix -e user-password.age"
  echo "    d) Rebuild:     sudo nixos-rebuild switch --flake ~/nix-config#nidhoggr"
else
  echo "  3. Run: sudo nixos-rebuild switch --flake ~/nix-config#homeserver"
fi
echo ""
read -p "Reboot now? [y/N] " REBOOT
if [ "$REBOOT" = "y" ] || [ "$REBOOT" = "Y" ]; then
  reboot
fi
