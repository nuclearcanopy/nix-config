#!/usr/bin/env bash
gov=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "powersave")
boost=$(cat /sys/devices/system/cpu/cpufreq/boost 2>/dev/null || echo "1")

if [ "$gov" = "performance" ]; then
  sudo set-cpu-mode bal
elif [ "$gov" = "powersave" ] && [ "$boost" = "1" ]; then
  sudo set-cpu-mode lap
else
  sudo set-cpu-mode spd
fi

pkill -RTMIN+3 waybar 2>/dev/null || true
