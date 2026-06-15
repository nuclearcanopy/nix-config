#!/usr/bin/env bash
BAT=/sys/class/power_supply/BAT1
{
  read -r STATUS      < "$BAT/status"
  read -r CAPACITY    < "$BAT/capacity"
  read -r ENERGY_NOW  < "$BAT/energy_now"
  read -r ENERGY_FULL < "$BAT/energy_full"
  read -r POWER_NOW   < "$BAT/power_now"
} 2>/dev/null

AC_ONLINE=0
[[ -r /sys/class/power_supply/AC/online ]] && read -r AC_ONLINE < /sys/class/power_supply/AC/online

CAPACITY=${CAPACITY:-0}
((CAPACITY > 99)) && CAPACITY=99

HOURS="--"
if [[ -n "$POWER_NOW" && "$POWER_NOW" -gt 0 ]]; then
  case "$STATUS" in
    Charging)
      [[ -n "$ENERGY_FULL" && -n "$ENERGY_NOW" ]] && \
        HOURS=$(( (ENERGY_FULL - ENERGY_NOW) / POWER_NOW )) ;;
    Discharging)
      [[ -n "$ENERGY_NOW" ]] && HOURS=$((ENERGY_NOW / POWER_NOW)) ;;
  esac
  if [[ "$HOURS" != "--" ]]; then
    ((HOURS > 99)) && HOURS=99
    printf -v HOURS '%02d' "$HOURS"
  fi
fi

if [[ "$STATUS" == "Charging" ]]; then
  printf 'CHG %02d%% %sH\n' "$CAPACITY" "$HOURS"
elif [[ "$AC_ONLINE" == "1" ]]; then
  printf 'PWR %02d%% --H\n' "$CAPACITY"
else
  if ((CAPACITY <= 10)); then
    printf "<span color='#B96B6B'>BAT %02d%% %sH</span>\n" "$CAPACITY" "$HOURS"
  elif ((CAPACITY <= 25)); then
    printf "<span color='#e5c07b'>BAT %02d%% %sH</span>\n" "$CAPACITY" "$HOURS"
  else
    printf 'BAT %02d%% %sH\n' "$CAPACITY" "$HOURS"
  fi
fi
