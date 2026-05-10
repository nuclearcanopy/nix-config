#!/usr/bin/env bash
# find k10temp (AMD) or coretemp (Intel) hwmon
for hwmon in /sys/class/hwmon/hwmon*; do
  name=$(cat "$hwmon/name" 2>/dev/null)
  if [ "$name" = "k10temp" ] || [ "$name" = "coretemp" ]; then
    TEMP=$(cat "$hwmon/temp1_input" 2>/dev/null)
    break
  fi
done

TEMP=${TEMP:-0}
TEMP=$((TEMP / 1000))
USAGE=$(awk '/^cpu / {usage=100-($5*100/($2+$3+$4+$5+$6+$7+$8))} END {printf "%.0f", usage}' /proc/stat)
((USAGE > 99)) && USAGE=99
printf "CPU %02d° %02d%%\n" "$TEMP" "$USAGE"
