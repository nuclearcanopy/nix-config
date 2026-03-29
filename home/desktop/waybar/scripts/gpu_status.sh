#!/usr/bin/env bash
TEMP=$(cat /sys/class/hwmon/hwmon5/temp2_input 2>/dev/null)
TEMP=$((TEMP / 1000))
USAGE=$(cat /sys/class/hwmon/hwmon5/device/gpu_busy_percent 2>/dev/null)
((USAGE > 99)) && USAGE=99
printf "GPU %02d° %02d%%\n" "$TEMP" "$USAGE"
