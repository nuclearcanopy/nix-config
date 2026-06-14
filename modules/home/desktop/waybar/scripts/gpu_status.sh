#!/usr/bin/env bash
TEMP=0; USAGE=0
for hwmon in /sys/class/hwmon/hwmon*; do
  { read -r name < "$hwmon/name"; } 2>/dev/null
  if [[ "$name" == "amdgpu" ]]; then
    { read -r TEMP  < "$hwmon/temp2_input"; }              2>/dev/null
    { read -r USAGE < "$hwmon/device/gpu_busy_percent"; }  2>/dev/null
    break
  fi
done
TEMP=$((TEMP / 1000))
((USAGE > 99)) && USAGE=99
printf 'GPU %02d° %02d%%\n' "$TEMP" "$USAGE"
