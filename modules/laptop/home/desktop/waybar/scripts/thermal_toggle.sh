#!/usr/bin/env bash
gov=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "powersave")
no_turbo=$(cat /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || echo "0")

# Left-click cycles: lap → bal → spd → lap
# Middle-click (from waybar config) → god
if [ "$gov" = "performance" ]; then
  set-cpu-mode lap
elif [ "$gov" = "powersave" ] && [ "$no_turbo" = "1" ]; then
  set-cpu-mode bal
else
  set-cpu-mode spd
fi

pkill -SIGRTMIN+3 waybar 2>/dev/null || true
