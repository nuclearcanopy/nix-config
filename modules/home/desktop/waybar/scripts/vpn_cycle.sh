#!/usr/bin/env bash
# Cycles Mullvad VPN through a fixed list of countries.
# Usage: vpn_cycle.sh [next|prev|last]
#   next  - advance to next country (left click)
#   prev  - go to previous country (right click)
#   last  - jump to last country in list (middle click)

COUNTRIES=(ch de se pl us ro)
STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/vpn-cycle-index"

mkdir -p "$(dirname "$STATE_FILE")"

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
  next)
    idx=$(( (idx + 1) % ${#COUNTRIES[@]} ))
    ;;
  prev)
    idx=$(( (idx - 1 + ${#COUNTRIES[@]}) % ${#COUNTRIES[@]} ))
    ;;
  last)
    idx=$(( ${#COUNTRIES[@]} - 1 ))
    ;;
esac

echo "$idx" > "$STATE_FILE"
mullvad relay set location "${COUNTRIES[$idx]}"
pkill -SIGRTMIN+9 waybar
