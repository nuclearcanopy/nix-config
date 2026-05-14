#!/usr/bin/env bash
gov=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "powersave")
no_turbo=$(cat /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || echo "0")
pl1=$(cat /sys/devices/virtual/powercap/intel-rapl/intel-rapl:0/constraint_0_power_limit_uw 2>/dev/null || echo "0")

# Cycle: lap → bal → spd → god → lap
if [ "$gov" = "performance" ] && [ "$pl1" -ge 45000000 ] 2>/dev/null; then
  set-cpu-mode lap
elif [ "$gov" = "performance" ]; then
  set-cpu-mode god
elif [ "$gov" = "powersave" ] && [ "$no_turbo" = "0" ]; then
  set-cpu-mode spd
else
  set-cpu-mode bal
fi

pkill -RTMIN+3 waybar 2>/dev/null || true
