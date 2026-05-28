#!/usr/bin/env bash
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/waybar-vis"
mkdir -p "$(dirname "$STATE")"

current=$(cat "$STATE" 2>/dev/null || echo "VIS")

if [ "$current" = "HID" ]; then
  echo "VIS" > "$STATE"
else
  echo "HID" > "$STATE"
  pkill -SIGUSR1 waybar
fi

pkill -SIGRTMIN+7 waybar
