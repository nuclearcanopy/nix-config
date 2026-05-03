#!/usr/bin/env bash
gov=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "?")
boost=$(cat /sys/devices/system/cpu/cpufreq/boost 2>/dev/null || echo "1")

case "$gov" in
  performance)
    echo "SPD"
    ;;
  powersave)
    if [ "$boost" = "0" ]; then
      echo "LAP"
    else
      echo "BAL"
    fi
    ;;
  *)
    echo "???"
    ;;
esac
