#!/usr/bin/env bash
gov=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "?")
no_turbo=$(cat /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || echo "0")

case "$gov" in
  performance)
    echo "SPD"
    ;;
  powersave)
    if [ "$no_turbo" = "1" ]; then
      echo "<span color='#B8A86A'>LAP</span>"
    else
      echo "BAL"
    fi
    ;;
  *)
    echo "???"
    ;;
esac
