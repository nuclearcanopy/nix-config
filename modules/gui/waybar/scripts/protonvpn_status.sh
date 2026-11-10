#!/usr/bin/env bash
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}"
MOVING_FLAG="$STATE_DIR/vpn-moving"

if [[ -f "$MOVING_FLAG" ]]; then
  echo "<span color='#C6A857'>VPN [CONNECTING]</span>"
  exit 0
fi

status="$(protonvpn status 2>/dev/null || true)"
state="$(sed -n 's/^Status: //p' <<< "$status")"

if [[ "$state" == "Connected" ]]; then
  server="$(sed -n 's/^Server: //p' <<< "$status")"
  cc="${server%%#*}"
  cc="${cc,,}"
  declare -A country_map=(
    [ch]=CHE [de]=DEU [se]=SWE [pl]=POL [us]=USA [ro]=ROU
  )
  country="${country_map[${cc:-xx}]:-???}"
  echo "VPN [PROTON · $country]"
elif [[ "$state" == "Connecting" || "$state" == "Reconnecting" ]]; then
  echo "<span color='#C6A857'>VPN [CONNECTING]</span>"
elif [[ -z "$status" ]]; then
  echo "<span color='#B96B6B'>VPN [UNAVAILABLE]</span>"
else
  echo "<span color='#B96B6B'>VPN [OFF]</span>"
fi
