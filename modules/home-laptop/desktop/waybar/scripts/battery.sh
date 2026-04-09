#!/usr/bin/env bash
# Battery status for waybar - caps at 99% for 2-digit width, shows hours remaining
BAT=/sys/class/power_supply/BAT0
STATUS=$(cat "$BAT/status" 2>/dev/null)
CAPACITY=$(cat "$BAT/capacity" 2>/dev/null)
ENERGY_NOW=$(cat "$BAT/energy_now" 2>/dev/null)
POWER_NOW=$(cat "$BAT/power_now" 2>/dev/null)

CAPACITY=${CAPACITY:-0}
((CAPACITY > 99)) && CAPACITY=99

# Calculate hours remaining (00-99, capped)
HOURS="--"
if [[ -n "$POWER_NOW" && "$POWER_NOW" -gt 0 && -n "$ENERGY_NOW" ]]; then
  HOURS=$((ENERGY_NOW / POWER_NOW))
  ((HOURS > 99)) && HOURS=99
  HOURS=$(printf "%02d" "$HOURS")
fi

case "$STATUS" in
  Charging|Full|"Not charging")
    printf "CHG %02d%% %sH\n" "$CAPACITY" "$HOURS"
    ;;
  *)
    if ((CAPACITY <= 10)); then
      printf "<span color='#B96B6B'>BAT %02d%% %sH</span>\n" "$CAPACITY" "$HOURS"
    elif ((CAPACITY <= 25)); then
      printf "<span color='#e5c07b'>BAT %02d%% %sH</span>\n" "$CAPACITY" "$HOURS"
    else
      printf "BAT %02d%% %sH\n" "$CAPACITY" "$HOURS"
    fi
    ;;
esac
