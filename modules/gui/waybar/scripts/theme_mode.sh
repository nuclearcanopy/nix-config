#!/usr/bin/env bash
# Reflects the persisted light/dark mode set by set-theme-mode.
mode=$(cat "$HOME/.local/state/theme-mode/current" 2>/dev/null || echo dark)
if [ "$mode" = "light" ]; then
  echo "LGT"
else
  echo "DRK"
fi
