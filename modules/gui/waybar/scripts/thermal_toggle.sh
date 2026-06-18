#!/usr/bin/env bash
gov=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "powersave")
no_turbo=$(cat /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || echo "0")

# Left-click  (next): lap → bal → spd → lap
# Right-click (prev): lap → spd → bal → lap
# Middle-click (from waybar config) → god
case "${1:-next}" in
  prev)
    if [ "$gov" = "performance" ]; then
      set-cpu-mode bal
    elif [ "$gov" = "powersave" ] && [ "$no_turbo" = "1" ]; then
      set-cpu-mode spd
    else
      set-cpu-mode lap
    fi
    ;;
  *)
    if [ "$gov" = "performance" ]; then
      set-cpu-mode lap
    elif [ "$gov" = "powersave" ] && [ "$no_turbo" = "1" ]; then
      set-cpu-mode bal
    else
      set-cpu-mode spd
    fi
    ;;
esac

pkill -SIGRTMIN+3 waybar 2>/dev/null || true
