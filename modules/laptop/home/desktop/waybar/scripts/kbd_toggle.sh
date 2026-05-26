#!/usr/bin/env bash
STATE_FILE="$HOME/.local/state/kbd-mode"
mkdir -p "$(dirname "$STATE_FILE")"

# find the T480 internal PS/2 keyboard
INTERNAL_KBD=$(swaymsg -t get_inputs 2>/dev/null \
  | grep '"identifier"' \
  | grep -i "AT_Translated" \
  | sed 's/.*"identifier": "//;s/".*//' \
  | head -1)

if [ -f "$STATE_FILE" ] && [ "$(cat "$STATE_FILE")" = "hhkb" ]; then
  swaymsg input '*' xkb_options "ctrl:nocaps,ctrl:swap_lalt_lctl"
  [ -n "$INTERNAL_KBD" ] && swaymsg input "$INTERNAL_KBD" events enabled
  echo "dflt" > "$STATE_FILE"
else
  swaymsg input '*' xkb_options ""
  [ -n "$INTERNAL_KBD" ] && swaymsg input "$INTERNAL_KBD" events disabled
  echo "hhkb" > "$STATE_FILE"
fi

pkill -SIGRTMIN+6 waybar 2>/dev/null || true
