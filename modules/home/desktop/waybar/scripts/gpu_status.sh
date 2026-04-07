#!/usr/bin/env bash
# find amdgpu hwmon
for hwmon in /sys/class/hwmon/hwmon*; do
  if [ "$(cat "$hwmon/name" 2>/dev/null)" = "amdgpu" ]; then
    TEMP=$(cat "$hwmon/temp2_input" 2>/dev/null)
    USAGE=$(cat "$hwmon/device/gpu_busy_percent" 2>/dev/null)
    break
  fi
done

TEMP=${TEMP:-0}
TEMP=$((TEMP / 1000))
USAGE=${USAGE:-0}
((USAGE > 99)) && USAGE=99
printf "GPU %02d° %02d%%\n" "$TEMP" "$USAGE"
