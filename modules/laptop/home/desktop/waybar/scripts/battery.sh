#!/usr/bin/env bash
# T480 has two batteries (BAT0 internal ~24Wh, BAT1 removable ~72Wh).
# Power Bridge treats them as one pool, so report a single combined %/time.
# Kernel exposes charge_*/current_now (µAh/µA) when both are present and
# energy_*/power_now (µWh/µW) when only one is; handle both.

shopt -s nullglob

# Accumulate in picowatt-hours and picowatts (µAh*µV or µWh*1e6) to keep
# everything in integer arithmetic.
TOTAL_NOW=0
TOTAL_FULL=0
TOTAL_POWER=0
ANY_CHARGING=0
ANY_DISCHARGING=0

for bat in /sys/class/power_supply/BAT*; do
  [[ -d "$bat" ]] || continue

  ST=Unknown
  V=0
  read -r ST < "$bat/status"      2>/dev/null
  read -r V  < "$bat/voltage_now" 2>/dev/null

  if [[ -r "$bat/charge_now" && -r "$bat/charge_full" ]]; then
    read -r CN < "$bat/charge_now"
    read -r CF < "$bat/charge_full"
    CI=0
    read -r CI < "$bat/current_now" 2>/dev/null
    TOTAL_NOW=$((  TOTAL_NOW  + CN * V ))
    TOTAL_FULL=$(( TOTAL_FULL + CF * V ))
    TOTAL_POWER=$((TOTAL_POWER + CI * V ))
  elif [[ -r "$bat/energy_now" && -r "$bat/energy_full" ]]; then
    read -r EN < "$bat/energy_now"
    read -r EF < "$bat/energy_full"
    PN=0
    read -r PN < "$bat/power_now" 2>/dev/null
    TOTAL_NOW=$((  TOTAL_NOW  + EN * 1000000 ))
    TOTAL_FULL=$(( TOTAL_FULL + EF * 1000000 ))
    TOTAL_POWER=$((TOTAL_POWER + PN * 1000000 ))
  else
    continue
  fi

  case "$ST" in
    Charging)    ANY_CHARGING=1 ;;
    Discharging) ANY_DISCHARGING=1 ;;
  esac
done

AC_ONLINE=0
[[ -r /sys/class/power_supply/AC/online ]] && read -r AC_ONLINE < /sys/class/power_supply/AC/online

CAPACITY=0
(( TOTAL_FULL > 0 )) && CAPACITY=$(( TOTAL_NOW * 100 / TOTAL_FULL ))
(( CAPACITY > 99 )) && CAPACITY=99
(( CAPACITY < 0  )) && CAPACITY=0

if   (( ANY_CHARGING ));    then STATUS=Charging
elif (( ANY_DISCHARGING )); then STATUS=Discharging
elif (( AC_ONLINE ));       then STATUS=Full
else                              STATUS=Discharging
fi

HOURS="--"
if (( TOTAL_POWER > 0 )); then
  case "$STATUS" in
    Charging)
      REMAINING=$(( TOTAL_FULL - TOTAL_NOW ))
      (( REMAINING > 0 )) && HOURS=$(( REMAINING / TOTAL_POWER )) ;;
    Discharging)
      HOURS=$(( TOTAL_NOW / TOTAL_POWER )) ;;
  esac
  if [[ "$HOURS" != "--" ]]; then
    (( HOURS > 99 )) && HOURS=99
    printf -v HOURS '%02d' "$HOURS"
  fi
fi

case "$STATUS" in
  Charging)
    printf 'CHG %02d%% %sH\n' "$CAPACITY" "$HOURS" ;;
  Full)
    printf 'PWR %02d%% --H\n' "$CAPACITY" ;;
  *)
    if   (( CAPACITY <= 10 )); then printf "<span color='#B96B6B'>BAT %02d%% %sH</span>\n" "$CAPACITY" "$HOURS"
    elif (( CAPACITY <= 25 )); then printf "<span color='#e5c07b'>BAT %02d%% %sH</span>\n" "$CAPACITY" "$HOURS"
    else                            printf 'BAT %02d%% %sH\n' "$CAPACITY" "$HOURS"
    fi ;;
esac
