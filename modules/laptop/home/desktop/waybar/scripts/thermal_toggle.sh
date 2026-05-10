#!/usr/bin/env bash
gov=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "powersave")
no_turbo=$(cat /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || echo "0")

if [ "$gov" = "performance" ]; then
  set-cpu-mode bal
elif [ "$gov" = "powersave" ] && [ "$no_turbo" = "0" ]; then
  set-cpu-mode lap
else
  set-cpu-mode spd
fi

pkill -RTMIN+3 waybar 2>/dev/null || true
