#!/usr/bin/env bash
# Cycles Mullvad VPN through a fixed list of countries.
# Usage: vpn_cycle.sh [next|prev|last]
#   next  - advance to next country (left click)
#   prev  - go to previous country (right click)
#   last  - jump to last country in list (middle click)

COUNTRIES=(ch de se pl us ro)
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_FILE="$STATE_DIR/vpn-cycle-index"
MOVING_FLAG="$STATE_DIR/vpn-moving"

mkdir -p "$STATE_DIR"

# Read current index, default to last (ro) if file missing
if [[ -f "$STATE_FILE" ]]; then
  idx=$(cat "$STATE_FILE")
else
  idx=$((${#COUNTRIES[@]} - 1))
fi

# Clamp to valid range
if ! [[ "$idx" =~ ^[0-9]+$ ]] || (( idx >= ${#COUNTRIES[@]} )); then
  idx=$((${#COUNTRIES[@]} - 1))
fi

case "${1:-next}" in
  next) idx=$(( (idx + 1) % ${#COUNTRIES[@]} )) ;;
  prev) idx=$(( (idx - 1 + ${#COUNTRIES[@]}) % ${#COUNTRIES[@]} )) ;;
  last) idx=$(( ${#COUNTRIES[@]} - 1 )) ;;
esac

echo "$idx" > "$STATE_FILE"

# Show yellow "MOVING.." while connecting; trap ensures flag is cleared even
# if mullvad hangs or the script is killed.
trap 'rm -f "$MOVING_FLAG"; pkill -SIGRTMIN+9 waybar 2>/dev/null || true' EXIT
target="${COUNTRIES[$idx]}"
touch "$MOVING_FLAG"
pkill -SIGRTMIN+9 waybar

mullvad relay set location "$target"

# Wait until mullvad reports Connected to the requested country. Checking
# only "Connected" is racy: `relay set location` returns before the daemon
# tears down the old tunnel, so status briefly still shows the old relay
# and the loop would break instantly, clearing MOVING before waybar refreshes.
for _ in $(seq 1 60); do
  status=$(mullvad status 2>/dev/null)
  if [[ "$status" == Connected* ]]; then
    relay=$(awk '/Relay:/ {print $2; exit}' <<< "$status")
    cc="${relay%%-*}"
    [[ "${cc,,}" == "$target" ]] && break
  fi
  sleep 0.5
done
