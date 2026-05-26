#!/usr/bin/env bash
STATE_FILE="$HOME/.local/state/kbd-mode"
mkdir -p "$(dirname "$STATE_FILE")"

INTERNAL_KBD="1:2:AT_Raw_Set_2_keyboard"

if [ -f "$STATE_FILE" ] && [ "$(cat "$STATE_FILE")" = "hhkb" ]; then
  swaymsg input "$INTERNAL_KBD" events enabled
  echo "dflt" > "$STATE_FILE"
else
  swaymsg input "$INTERNAL_KBD" events disabled
  echo "hhkb" > "$STATE_FILE"
fi

pkill -SIGRTMIN+6 waybar 2>/dev/null || true
