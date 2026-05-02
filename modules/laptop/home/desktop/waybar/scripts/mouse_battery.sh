#!/usr/bin/env bash
# Logitech G502X LIGHTSPEED battery via HID++ kernel driver
BAT=/sys/class/power_supply/hidpp_battery_0
CAPACITY=$(cat "$BAT/capacity" 2>/dev/null)
STATUS=$(cat "$BAT/status" 2>/dev/null)

[[ -n "$CAPACITY" ]] || exit 0

if [[ "$STATUS" == "Charging" ]]; then
  printf "MSE CHG %02d%%\n" "$CAPACITY"
elif ((CAPACITY <= 10)); then
  printf "<span color='#B96B6B'>MSE %02d%%</span>\n" "$CAPACITY"
elif ((CAPACITY <= 25)); then
  printf "<span color='#e5c07b'>MSE %02d%%</span>\n" "$CAPACITY"
else
  printf "MSE %02d%%\n" "$CAPACITY"
fi
