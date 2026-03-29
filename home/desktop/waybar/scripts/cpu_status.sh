#!/usr/bin/env bash
TEMP=$(cat /sys/class/hwmon/hwmon1/temp1_input 2>/dev/null)
TEMP=$((TEMP / 1000))
USAGE=$(awk '/^cpu / {usage=100-($5*100/($2+$3+$4+$5+$6+$7+$8))} END {printf "%.0f", usage}' /proc/stat)
echo "CPU ${TEMP}° ${USAGE}%"
