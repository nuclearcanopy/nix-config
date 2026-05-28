#!/usr/bin/env bash
# hide waybar on startup if last state was HID
sleep 2
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/waybar-vis"
state=$(cat "$STATE" 2>/dev/null || echo "VIS")
[ "$state" = "HID" ] && pkill -SIGUSR1 waybar
