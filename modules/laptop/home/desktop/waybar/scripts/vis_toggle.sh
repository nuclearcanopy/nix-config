#!/usr/bin/env bash
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/waybar-vis"
mkdir -p "$(dirname "$STATE")"

current=$(cat "$STATE" 2>/dev/null || echo "HID")

if [ "$current" = "HID" ]; then
  echo "VIS" > "$STATE"
  swaymsg 'unbindsym --no-repeat Control+space'
  swaymsg 'unbindsym --release Control+space'
else
  echo "HID" > "$STATE"
  pkill -SIGUSR1 waybar
  swaymsg 'bindsym --no-repeat Control+space exec pkill -SIGUSR1 waybar'
  swaymsg 'bindsym --release Control+space exec pkill -SIGUSR1 waybar'
fi

pkill -SIGRTMIN+7 waybar
