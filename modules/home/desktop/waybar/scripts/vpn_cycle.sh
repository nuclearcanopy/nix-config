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

# Show MOVING.. while connecting
touch "$MOVING_FLAG"
pkill -SIGRTMIN+9 waybar

mullvad relay set location "${COUNTRIES[$idx]}"

# Wait for connection before clearing flag (up to 30s)
for _ in $(seq 1 30); do
  mullvad status | grep -q "^Connected" && break
  sleep 1
done

rm -f "$MOVING_FLAG"
pkill -SIGRTMIN+9 waybar
