#!/usr/bin/env bash
# Find k10temp (AMD CPU) hwmon dynamically
for hwmon in /sys/class/hwmon/hwmon*; do
  if [ "$(cat "$hwmon/name" 2>/dev/null)" = "k10temp" ]; then
    TEMP=$(cat "$hwmon/temp1_input" 2>/dev/null)
    break
  fi
done

TEMP=${TEMP:-0}
TEMP=$((TEMP / 1000))
USAGE=$(awk '/^cpu / {usage=100-($5*100/($2+$3+$4+$5+$6+$7+$8))} END {printf "%.0f", usage}' /proc/stat)
((USAGE > 99)) && USAGE=99
printf "CPU %02d° %02d%%\n" "$TEMP" "$USAGE"
