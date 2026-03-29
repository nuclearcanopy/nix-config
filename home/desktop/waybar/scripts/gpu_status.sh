#!/usr/bin/env bash
TEMP=$(cat /sys/class/hwmon/hwmon5/temp2_input 2>/dev/null)
TEMP=$((TEMP / 1000))
USAGE=$(cat /sys/class/hwmon/hwmon5/device/gpu_busy_percent 2>/dev/null)
echo "GPU ${TEMP}° ${USAGE}%"
