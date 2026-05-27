#!/usr/bin/env bash
# restore vis mode state on sway startup (waybar starts via systemd, needs brief delay)
sleep 2
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/waybar-vis"
state=$(cat "$STATE" 2>/dev/null)
if [ "$state" = "VIS" ]; then
  pkill -SIGUSR1 waybar
  swaymsg 'unbindsym --no-repeat Control+space'
  swaymsg 'unbindsym --release Control+space'
fi
