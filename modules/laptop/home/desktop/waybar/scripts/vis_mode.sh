#!/usr/bin/env bash
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/waybar-vis"
cat "$STATE" 2>/dev/null || echo "HID"
