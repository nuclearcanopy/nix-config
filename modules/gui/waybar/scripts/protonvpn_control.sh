#!/usr/bin/env bash
# Waybar controls for Proton VPN: left/right cycle countries, middle toggles.
set -uo pipefail

COUNTRIES=(ch de se pl us ro)
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_FILE="$STATE_DIR/protonvpn-cycle-index"
MOVING_FLAG="$STATE_DIR/vpn-moving"

mkdir -p "$STATE_DIR"

idx=$(cat "$STATE_FILE" 2>/dev/null || true)
if [[ -z "$idx" ]]; then
  idx=$((${#COUNTRIES[@]} - 1))
fi
if ! [[ "$idx" =~ ^[0-9]+$ ]] || (( idx >= ${#COUNTRIES[@]} )); then
  idx=$((${#COUNTRIES[@]} - 1))
fi

case "${1:-toggle}" in
  next) idx=$(( (idx + 1) % ${#COUNTRIES[@]} ));;
  prev) idx=$(( (idx - 1 + ${#COUNTRIES[@]}) % ${#COUNTRIES[@]} ));;
  toggle) ;;
  *) echo "Usage: $0 [next|prev|toggle]" >&2; exit 2;;
esac

trap 'rm -f "$MOVING_FLAG"; pkill -SIGRTMIN+9 waybar 2>/dev/null || true' EXIT
touch "$MOVING_FLAG"
pkill -SIGRTMIN+9 waybar 2>/dev/null || true

status="$(protonvpn status 2>/dev/null || true)"
connected="$(sed -n 's/^Status: //p' <<< "$status")"

if [[ "${1:-toggle}" == "toggle" ]]; then
  if [[ "$connected" == "Connected" ]]; then
    protonvpn disconnect
  else
    protonvpn config set kill-switch standard && protonvpn connect
  fi
  exit $?
fi

echo "$idx" > "$STATE_FILE"
target="${COUNTRIES[$idx]}"
protonvpn config set kill-switch standard || exit $?
protonvpn connect --country "$target" || exit $?

# Wait for the requested country, not just any Connected state: connect may
# return before the previous tunnel has finished tearing down.
for _ in $(seq 1 60); do
  status="$(protonvpn status 2>/dev/null || true)"
  connected="$(sed -n 's/^Status: //p' <<< "$status")"
  server="$(sed -n 's/^Server: //p' <<< "$status")"
  if [[ "$connected" == "Connected" && "${server,,}" == "$target#"* ]]; then
    break
  fi
  sleep 0.5
done
