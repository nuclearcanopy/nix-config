#!/usr/bin/env bash
STATE_FILE="$HOME/.local/state/kbd-mode"
if [ -f "$STATE_FILE" ] && [ "$(cat "$STATE_FILE")" = "hhkb" ]; then
  echo "HHKB"
else
  echo "DFLT"
fi
