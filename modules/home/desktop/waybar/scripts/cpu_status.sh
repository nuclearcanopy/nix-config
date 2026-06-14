#!/usr/bin/env bash
TEMP=0
for hwmon in /sys/class/hwmon/hwmon*; do
  { read -r name < "$hwmon/name"; } 2>/dev/null
  if [[ "$name" == "k10temp" || "$name" == "coretemp" ]]; then
    { read -r TEMP < "$hwmon/temp1_input"; } 2>/dev/null
    break
  fi
done
TEMP=$((TEMP / 1000))

read -r _ u n s i io irq sirq _ < /proc/stat
total=$((u + n + s + i + io + irq + sirq))
USAGE=$(( 100 - (i * 100 / total) ))
((USAGE > 99)) && USAGE=99
printf 'CPU %02d° %02d%%\n' "$TEMP" "$USAGE"
