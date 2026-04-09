#!/usr/bin/env bash
# Battery status for waybar - caps at 99% to maintain 2-digit width
STATUS=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null)
CAPACITY=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null)
CAPACITY=${CAPACITY:-0}
((CAPACITY > 99)) && CAPACITY=99

case "$STATUS" in
  Charging|Full|"Not charging")
    printf "CHG %02d%%\n" "$CAPACITY"
    ;;
  *)
    if ((CAPACITY <= 10)); then
      printf "<span color='#B96B6B'>BAT %02d%%</span>\n" "$CAPACITY"
    elif ((CAPACITY <= 25)); then
      printf "<span color='#e5c07b'>BAT %02d%%</span>\n" "$CAPACITY"
    else
      printf "BAT %02d%%\n" "$CAPACITY"
    fi
    ;;
esac
