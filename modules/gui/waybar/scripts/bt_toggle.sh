#!/usr/bin/env bash
state=$(bluetoothctl show 2>/dev/null | awk '/Powered:/ {print $2; exit}')
if [ "$state" = "yes" ]; then
  bluetoothctl power off >/dev/null 2>&1 || true
else
  bluetoothctl power on >/dev/null 2>&1 || true
fi
pkill -RTMIN+12 waybar 2>/dev/null || true
