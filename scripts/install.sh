#!/usr/bin/env bash
set -e

# NixOS Installer with Modern TUI
# Requires: nix with flakes enabled (standard on NixOS live ISO)

# ═══════════════════════════════════════════════════════════════════════════════
# BOOTSTRAP: Ensure gum is available
# ═══════════════════════════════════════════════════════════════════════════════

if ! command -v gum &>/dev/null; then
  echo "Installing TUI dependencies..."
  nix profile install nixpkgs#gum --extra-experimental-features "nix-command flakes" 2>/dev/null || {
    export PATH="$(nix build nixpkgs#gum --no-link --print-out-paths --extra-experimental-features 'nix-command flakes' 2>/dev/null)/bin:$PATH"
  }
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STYLES
# ═══════════════════════════════════════════════════════════════════════════════

export GUM_CHOOSE_CURSOR_FOREGROUND="6"
export GUM_CHOOSE_SELECTED_FOREGROUND="2"
export GUM_SPIN_SPINNER="dots"
export GUM_SPIN_SPINNER_FOREGROUND="6"
export GUM_INPUT_CURSOR_FOREGROUND="6"
export GUM_INPUT_PROMPT_FOREGROUND="8"
export GUM_CONFIRM_SELECTED_BACKGROUND="2"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# ═══════════════════════════════════════════════════════════════════════════════
# STATE - These persist across steps
# ═══════════════════════════════════════════════════════════════════════════════

HOST=""
USERNAME=""
DISK=""
AGE_KEY_METHOD=""  # paste, file, generate, existing
AGE_KEY=""         # actual key if pasted
AGE_PUBKEY=""      # pubkey if generated
DEFAULT_USERNAME=""
DEFAULT_DISK=""
LOG=""

# Discovered from flake
declare -a HOSTS=()
declare -A HOST_USERNAMES=()
declare -A HOST_DISKS=()
declare -A HOST_DESCRIPTIONS=()

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIG DISCOVERY - Read hosts/users/disks from flake
# ═══════════════════════════════════════════════════════════════════════════════

discover_config() {
  # Get nix-config directory (parent of scripts/)
  local script_dir
  if [ -n "${BASH_SOURCE[0]}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  else
    # Fallback: assume we're in nix-config or it's in pwd
    script_dir="$(pwd)"
    [ -d "$script_dir/hosts" ] || script_dir="$(dirname "$(pwd)")"
  fi

  # Validate we found the right directory
  if [ ! -f "$script_dir/flake.nix" ]; then
    echo -e "${RED}Error:${NC} Cannot find flake.nix. Run from nix-config directory."
    exit 1
  fi

  # Discover hosts from hosts/*/configuration.nix
  for host_dir in "$script_dir"/hosts/*/; do
    if [ -f "${host_dir}configuration.nix" ]; then
      local host_name
      host_name=$(basename "$host_dir")
      HOSTS+=("$host_name")

      # Get default disk from disko.nix (first line: { device ? "/dev/xxx", ... })
      if [ -f "${host_dir}disko.nix" ]; then
        local disk
        disk=$(grep -oP 'device \? "\K[^"]+' "${host_dir}disko.nix" 2>/dev/null | head -1)
        HOST_DISKS["$host_name"]="${disk:-/dev/sda}"
      else
        HOST_DISKS["$host_name"]="/dev/sda"
      fi

      # Try to get description from configuration.nix comments or README
      # For now, use host name as description; can be enhanced later
      HOST_DESCRIPTIONS["$host_name"]="$host_name"
    fi
  done

  # Get default username from flake.nix
  local flake_username
  flake_username=$(grep -oP '^\s*username\s*=\s*"\K[^"]+' "$script_dir/flake.nix" 2>/dev/null | head -1)

  # Assign usernames - check if host has its own username in specialArgs
  for host in "${HOSTS[@]}"; do
    # Check if this host has a different username in flake.nix
    # Look for specialArgs in the host's nixosSystem block
    local host_user
    host_user=$(awk "/nixosConfigurations\.$host|$host = nixpkgs.lib.nixosSystem/,/};/" "$script_dir/flake.nix" 2>/dev/null | \
      grep -oP 'username\s*=\s*"\K[^"]+' | head -1)

    if [ -n "$host_user" ]; then
      HOST_USERNAMES["$host"]="$host_user"
    elif [ -n "$flake_username" ]; then
      HOST_USERNAMES["$host"]="$flake_username"
    else
      # Fallback: use host name for servers, generic for others
      if [[ "$host" == *"server"* ]]; then
        HOST_USERNAMES["$host"]="$host"
      else
        HOST_USERNAMES["$host"]="user"
      fi
    fi
  done

  # If no hosts found, error out
  if [ ${#HOSTS[@]} -eq 0 ]; then
    echo -e "${RED}Error:${NC} No hosts found in hosts/*/"
    exit 1
  fi
}

# Build gum choose options for hosts
build_host_menu() {
  local options=()
  for host in "${HOSTS[@]}"; do
    local disk="${HOST_DISKS[$host]}"
    local user="${HOST_USERNAMES[$host]}"
    # Format: "hostname  │ user@disk"
    options+=("$(printf "%-12s│ %s @ %s" "$host" "$user" "$disk")")
  done
  options+=("← Quit")
  printf '%s\n' "${options[@]}"
}

# ═══════════════════════════════════════════════════════════════════════════════
# UTILITIES
# ═══════════════════════════════════════════════════════════════════════════════

header() {
  clear
  gum style \
    --border rounded \
    --border-foreground 6 \
    --padding "0 2" \
    --margin "1 0" \
    "$(gum style --foreground 6 --bold 'NixOS Installer') $(gum style --foreground 8 '// flake-based')"
  echo ""
}

step_header() {
  local step=$1
  local total=$2
  local title=$3
  gum style --foreground 8 "[$step/$total] $(gum style --foreground 7 --bold "$title")"
}

success() { gum style --foreground 2 "✓ $1"; }
warn() { gum style --foreground 3 "! $1"; }
error() { gum style --foreground 1 "✗ $1"; }
info() { gum style --foreground 8 "  $1"; }

ts() { date +"%H:%M:%S"; }
now_s() { date +%s; }

elapsed() {
  local diff=$(($2 - $1))
  printf "%dm%02ds" "$((diff / 60))" "$((diff % 60))"
}

# Show current selections in a subtle way
show_breadcrumb() {
  local parts=()
  [ -n "$HOST" ] && parts+=("$HOST")
  [ -n "$USERNAME" ] && parts+=("$USERNAME")
  [ -n "$DISK" ] && parts+=("$DISK")

  if [ ${#parts[@]} -gt 0 ]; then
    gum style --foreground 8 "  ${parts[*]}"
    echo ""
  fi
}

# Navigation helper - returns "next", "back", or "quit"
nav_choice() {
  local choice
  choice=$(gum choose --height 4 "Continue →" "← Back" "Quit" | cut -d' ' -f1)
  case "$choice" in
    "Continue") echo "next" ;;
    "←") echo "back" ;;
    *) echo "quit" ;;
  esac
}

run_task() {
  local title=$1; shift
  local start_s rc
  start_s=$(now_s)
  echo "[$(ts)] START: $title" >> "$LOG"
  echo "[$(ts)] CMD: $*" >> "$LOG"

  set +e
  gum spin --title "$title" -- bash -c '"$@" >> "$LOG" 2>&1' _ "$@"
  rc=$?
  set -e

  echo "[$(ts)] END: $title (rc=$rc, elapsed=$(elapsed "$start_s" "$(now_s)"))" >> "$LOG"

  if [ "$rc" -ne 0 ]; then
    error "Failed: $title"
    echo ""
    gum style --foreground 8 "Last 20 lines of log:"
    tail -20 "$LOG" | gum style --foreground 1
    echo ""
    gum style --foreground 8 "Full log: $LOG"
    exit 1
  fi
}

run_task_windowed() {
  local title=$1; shift
  local start_s rc pid
  local window_height=12 window_width=80

  start_s=$(now_s)
  echo "[$(ts)] START: $title" >> "$LOG"
  echo "[$(ts)] CMD: $*" >> "$LOG"

  "$@" >> "$LOG" 2>&1 &
  pid=$!

  tput civis 2>/dev/null || true

  while kill -0 "$pid" 2>/dev/null; do
    draw_log_window "$title" "$window_height" "$window_width" "$start_s"
    sleep 0.3
  done

  set +e; wait "$pid"; rc=$?; set -e

  draw_log_window "$title" "$window_height" "$window_width" "$start_s"
  tput cnorm 2>/dev/null || true
  echo ""

  echo "[$(ts)] END: $title (rc=$rc, elapsed=$(elapsed "$start_s" "$(now_s)"))" >> "$LOG"

  if [ "$rc" -ne 0 ]; then
    error "Failed: $title"
    echo ""
    gum style --foreground 8 "Full log: $LOG"
    exit 1
  fi
}

draw_log_window() {
  local title=$1 height=$2 width=$3 start_s=$4
  local elapsed_str term_width

  elapsed_str=$(elapsed "$start_s" "$(now_s)")
  term_width=$(tput cols 2>/dev/null || echo 80)
  [ "$width" -gt "$((term_width - 4))" ] && width=$((term_width - 4))

  tput cup 8 0 2>/dev/null || printf '\033[9;0H'

  # Title bar
  local title_display="$title [$elapsed_str]"
  local pad_right=$((width - ${#title_display} - 2))
  [ "$pad_right" -lt 0 ] && pad_right=0

  printf '\033[36m╭─\033[1m %s \033[0m\033[36m' "$title_display"
  printf '─%.0s' $(seq 1 "$pad_right")
  printf '╮\033[0m\n'

  # Get interesting log lines
  local lines
  lines=$(tail -100 "$LOG" 2>/dev/null | \
    grep -iE '(copying|building|fetching|evaluating|installing|unpacking|patching|checking|these .* paths)' | \
    tail -"$height" | cut -c1-"$((width - 4))" || true)
  [ -z "$lines" ] && lines=$(tail -"$height" "$LOG" 2>/dev/null | cut -c1-"$((width - 4))" || true)

  # Draw lines
  local line_count=0
  while IFS= read -r line || [ -n "$line" ]; do
    printf '\033[36m│\033[0m \033[38;5;245m%-*s\033[0m \033[36m│\033[0m\n' "$((width - 4))" "$line"
    ((line_count++))
  done <<< "$lines"

  while [ "$line_count" -lt "$height" ]; do
    printf '\033[36m│\033[0m %-*s \033[36m│\033[0m\n' "$((width - 4))" ""
    ((line_count++))
  done

  # Bottom with spinner
  local spinners='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  local spin_idx=$(( $(date +%s) % 10 ))
  printf '\033[36m╰─\033[33m%s\033[36m─' "${spinners:$spin_idx:1}"
  printf '─%.0s' $(seq 1 "$((width - 4))")
  printf '╯\033[0m\n'
}

# ═══════════════════════════════════════════════════════════════════════════════
# STEP FUNCTIONS - Each returns "next", "back", or "quit"
# ═══════════════════════════════════════════════════════════════════════════════

step_host() {
  header
  step_header 1 5 "Select Host"
  echo ""

  info "Discovered ${#HOSTS[@]} host(s) from flake"
  echo ""

  local choice
  choice=$(build_host_menu | gum choose --height $((${#HOSTS[@]} + 2)))

  # Extract host name (first word before spaces)
  HOST=$(echo "$choice" | awk '{print $1}')

  case "$HOST" in
    "←"|"") return 1 ;;  # quit
  esac

  # Check if valid host
  if [[ ! " ${HOSTS[*]} " =~ " ${HOST} " ]]; then
    error "Invalid host: $HOST"
    return 1
  fi

  DEFAULT_USERNAME="${HOST_USERNAMES[$HOST]}"
  DEFAULT_DISK="${HOST_DISKS[$HOST]}"
  LOG="/tmp/${HOST}-install.log"

  success "Host: $HOST"
  info "Default user: $DEFAULT_USERNAME"
  info "Default disk: $DEFAULT_DISK"
  return 0
}

step_username() {
  header
  step_header 2 5 "Configure User"
  show_breadcrumb

  info "Press Enter to accept default"
  echo ""

  USERNAME=$(gum input --placeholder "$DEFAULT_USERNAME" --prompt "Username: " --value "${USERNAME:-$DEFAULT_USERNAME}")
  USERNAME="${USERNAME:-$DEFAULT_USERNAME}"

  echo ""
  success "Username: $USERNAME"
  echo ""

  local nav
  nav=$(nav_choice)
  case "$nav" in
    next) return 0 ;;
    back) return 2 ;;
    *) return 1 ;;
  esac
}

step_age_key() {
  header
  step_header 3 5 "Age Identity Key"
  show_breadcrumb

  gum style --foreground 8 --margin "0 0 1 0" \
    "All hosts share the same age key for secrets decryption."
  echo ""

  # Check for existing key
  if [ -f "/etc/age/key.txt" ]; then
    info "Found existing key at /etc/age/key.txt"
    if gum confirm "Use existing key?"; then
      AGE_KEY_METHOD="existing"
      success "Using existing age key"
      echo ""
      local nav; nav=$(nav_choice)
      case "$nav" in
        next) return 0 ;;
        back) return 2 ;;
        *) return 1 ;;
      esac
    fi
  fi

  AGE_KEY_METHOD=$(gum choose --height 5 \
    "paste    │ Type/paste your age key" \
    "file     │ I'll place it at /etc/age/key.txt" \
    "generate │ Generate new key" \
    "← Back" \
    | cut -d' ' -f1)

  case "$AGE_KEY_METHOD" in
    "←"|"") return 2 ;;
    paste)
      echo ""
      gum style --foreground 8 "Enter your age identity key (AGE-SECRET-KEY-...)"
      echo ""

      if gum confirm "Show key while typing?"; then
        AGE_KEY=$(gum input --prompt "Age key: " --width 80 --placeholder "AGE-SECRET-KEY-...")
      else
        AGE_KEY=$(gum input --prompt "Age key: " --width 80 --placeholder "AGE-SECRET-KEY-..." --password)
      fi

      if [ -z "$AGE_KEY" ]; then
        error "No key provided"
        sleep 1
        return 2
      fi

      if [[ ! "$AGE_KEY" =~ ^AGE-SECRET-KEY- ]]; then
        error "Invalid format (must start with AGE-SECRET-KEY-)"
        sleep 1
        return 2
      fi

      success "Age key accepted"
      ;;

    file)
      echo ""
      gum style --foreground 3 "Place your key at: /etc/age/key.txt"
      gum style --foreground 8 "Press Enter when ready..."
      read -r

      if [ ! -f "/etc/age/key.txt" ]; then
        error "Key not found"
        sleep 1
        return 2
      fi
      AGE_KEY_METHOD="file"
      success "Age key found"
      ;;

    generate)
      AGE_KEY_METHOD="generate"
      success "Will generate new key during install"
      ;;
  esac

  echo ""
  local nav; nav=$(nav_choice)
  case "$nav" in
    next) return 0 ;;
    back) AGE_KEY=""; AGE_KEY_METHOD=""; return 2 ;;
    *) return 1 ;;
  esac
}

step_disk() {
  header
  step_header 4 5 "Select Disk"
  show_breadcrumb

  gum style --foreground 8 "Available disks:"
  echo ""
  lsblk -d -o NAME,SIZE,MODEL | tail -n +2 | while read -r line; do
    gum style --foreground 7 "  $line"
  done
  echo ""

  DISK=$(gum input --placeholder "$DEFAULT_DISK" --prompt "Install disk: " --value "${DISK:-$DEFAULT_DISK}")
  DISK="${DISK:-$DEFAULT_DISK}"

  if [ ! -b "$DISK" ]; then
    error "Disk not found: $DISK"
    sleep 1
    DISK=""
    return 2
  fi

  echo ""
  gum style --foreground 1 --bold "⚠ This will WIPE $DISK"
  echo ""
  lsblk "$DISK" | while read -r line; do
    gum style --foreground 8 "  $line"
  done
  echo ""

  success "Disk: $DISK"
  echo ""

  local nav; nav=$(nav_choice)
  case "$nav" in
    next) return 0 ;;
    back) return 2 ;;
    *) return 1 ;;
  esac
}

step_confirm() {
  header
  step_header 5 5 "Review & Install"
  echo ""

  # Show summary
  gum style --border double --border-foreground 6 --padding "1 2" \
    "$(gum style --foreground 6 --bold 'Installation Summary')

  $(gum style --foreground 8 'Host:')     $(gum style --foreground 7 "$HOST")
  $(gum style --foreground 8 'User:')     $(gum style --foreground 7 "$USERNAME")
  $(gum style --foreground 8 'Disk:')     $(gum style --foreground 1 "$DISK") $(gum style --foreground 1 '(will be wiped!)')
  $(gum style --foreground 8 'Age key:')  $(gum style --foreground 7 "$AGE_KEY_METHOD")"

  echo ""

  local choice
  choice=$(gum choose --height 4 \
    "Install │ Begin installation (irreversible)" \
    "← Back  │ Change settings" \
    "Quit" \
    | cut -d' ' -f1)

  case "$choice" in
    "Install") return 0 ;;
    "←") return 2 ;;
    *) return 1 ;;
  esac
}

# ═══════════════════════════════════════════════════════════════════════════════
# INSTALLATION (no going back after this)
# ═══════════════════════════════════════════════════════════════════════════════

do_install() {
  header
  gum style --foreground 6 --bold "Installing NixOS"
  echo ""

  local START_ALL
  START_ALL=$(now_s)
  echo "[$(ts)] Installer started for ${HOST}" > "$LOG"

  # Prepare age key
  case "$AGE_KEY_METHOD" in
    paste)
      mkdir -p /etc/age
      echo "$AGE_KEY" > /etc/age/key.txt
      chmod 600 /etc/age/key.txt
      ;;
    generate)
      mkdir -p /etc/age
      local AGE_OUTPUT
      AGE_OUTPUT=$(age-keygen 2>&1)
      echo "$AGE_OUTPUT" | grep "AGE-SECRET-KEY" > /etc/age/key.txt
      chmod 600 /etc/age/key.txt
      AGE_PUBKEY=$(echo "$AGE_OUTPUT" | grep "public key:" | cut -d: -f2 | tr -d ' ')
      ;;
    # file/existing: already in place
  esac
  success "Age key ready"

  # Check disko
  local DISKO_PATH="./hosts/${HOST}/disko.nix"
  if [ ! -f "$DISKO_PATH" ]; then
    error "Disko config not found: $DISKO_PATH"
    exit 1
  fi

  # ═══════════════════════════════════════════════════════════════════════════
  # PRE-FLIGHT CHECK: Evaluate flake BEFORE wiping disk
  # Catches unfree package errors, missing deps, eval failures early
  # ═══════════════════════════════════════════════════════════════════════════
  echo ""
  gum style --foreground 6 "Pre-flight check: evaluating configuration..."
  gum style --foreground 8 "  (This catches errors before wiping your disk)"
  echo ""

  set +e
  PREFLIGHT_OUTPUT=$(nix build ".#nixosConfigurations.${HOST}.config.system.build.toplevel" \
    --dry-run \
    --show-trace \
    --extra-experimental-features "nix-command flakes" 2>&1)
  PREFLIGHT_RC=$?
  set -e

  if [ "$PREFLIGHT_RC" -ne 0 ]; then
    error "Configuration failed to evaluate!"
    echo ""
    gum style --foreground 1 --border rounded --padding "1" \
      "$PREFLIGHT_OUTPUT" | tail -50
    echo ""
    gum style --foreground 3 "Common causes:"
    gum style --foreground 8 "  • Unfree package not in allowUnfreePredicate"
    gum style --foreground 8 "  • Missing input or typo in module"
    gum style --foreground 8 "  • Syntax error in nix files"
    echo ""
    gum style --foreground 8 "Fix the issue and re-run the installer."
    exit 1
  fi

  success "Configuration evaluates cleanly"
  echo ""

  # Partition
  run_task_windowed "Partitioning disk" \
    nix --experimental-features "nix-command flakes" run .#disko -- --mode disko "$DISKO_PATH" --argstr device "$DISK"
  success "Disk partitioned"

  # Generate hardware config
  run_task "Generating hardware config..." nixos-generate-config --root /mnt
  cp /mnt/etc/nixos/hardware-configuration.nix "./hosts/${HOST}/hardware-configuration.nix"
  success "Hardware config generated"

  # Stage age key
  mkdir -p /mnt/etc/age
  cp /etc/age/key.txt /mnt/etc/age/key.txt
  chmod 600 /mnt/etc/age/key.txt
  success "Age key staged"

  # Install NixOS
  run_task_windowed "Installing NixOS" \
    nixos-install --flake ".#${HOST}" --no-root-password --show-trace
  success "NixOS installed"

  # Copy config
  local DEST="/mnt/home/${USERNAME}/nix-config"
  mkdir -p "$DEST"
  cp -r . "$DEST"
  local TARGET_UID TARGET_GID
  TARGET_UID=$(chroot /mnt id -u "${USERNAME}" 2>/dev/null || echo "1000")
  TARGET_GID=$(chroot /mnt id -g "${USERNAME}" 2>/dev/null || echo "users")
  chown -R "${TARGET_UID}:${TARGET_GID}" "/mnt/home/${USERNAME}"
  success "Config copied to ~/nix-config"

  echo ""

  # Done!
  header
  gum style --foreground 2 --bold "Installation Complete"
  echo ""

  local TOTAL_TIME
  TOTAL_TIME=$(elapsed "$START_ALL" "$(now_s)")

  gum style --border double --border-foreground 2 --padding "1 2" \
    "$(gum style --foreground 2 --bold '✓ NixOS installed successfully!')

  Total time: $(gum style --foreground 7 "$TOTAL_TIME")
  Log: $(gum style --foreground 8 "$LOG")"

  echo ""
  gum style --foreground 8 "Next steps:"
  gum style --foreground 7 "  1. Reboot"
  gum style --foreground 7 "  2. Log in as $USERNAME"
  gum style --foreground 7 "  3. sudo nixos-rebuild switch --flake ~/nix-config#$HOST"

  if [ -n "$AGE_PUBKEY" ]; then
    echo ""
    gum style --foreground 3 "New age key generated! Public key:"
    gum style --foreground 2 "  $AGE_PUBKEY"
    echo ""
    gum style --foreground 8 "Add to secrets/secrets.nix, then: cd ~/nix-config/secrets && agenix -r"
  fi

  echo ""
  if gum confirm "Reboot now?"; then
    reboot
  fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN - State machine loop
# ═══════════════════════════════════════════════════════════════════════════════

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Error:${NC} Run as root (sudo or doas)"
  exit 1
fi

# Discover hosts and config from flake before starting TUI
echo "Scanning flake configuration..."
discover_config
echo "Found hosts: ${HOSTS[*]}"
sleep 0.5

STEP=1

while true; do
  case $STEP in
    1)
      if step_host; then
        STEP=2
      else
        echo "Aborted."
        exit 0
      fi
      ;;
    2)
      step_username
      case $? in
        0) STEP=3 ;;
        2) STEP=1 ;;
        *) echo "Aborted."; exit 0 ;;
      esac
      ;;
    3)
      step_age_key
      case $? in
        0) STEP=4 ;;
        2) STEP=2 ;;
        *) echo "Aborted."; exit 0 ;;
      esac
      ;;
    4)
      step_disk
      case $? in
        0) STEP=5 ;;
        2) STEP=3 ;;
        *) echo "Aborted."; exit 0 ;;
      esac
      ;;
    5)
      step_confirm
      case $? in
        0) do_install; exit 0 ;;
        2) STEP=4 ;;
        *) echo "Aborted."; exit 0 ;;
      esac
      ;;
  esac
done
