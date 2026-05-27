#!/usr/bin/env bash
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/waybar-vis"
current=$(cat "$STATE" 2>/dev/null || echo "HID")
if [ "$current" = "VIS" ]; then
  echo '{"text": "VIS", "class": "active"}'
else
  echo '{"text": "HID"}'
fi
