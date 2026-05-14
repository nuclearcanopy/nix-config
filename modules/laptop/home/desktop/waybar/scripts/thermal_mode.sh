#!/usr/bin/env bash
gov=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "?")
no_turbo=$(cat /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || echo "0")
pl1=$(cat /sys/devices/virtual/powercap/intel-rapl/intel-rapl:0/constraint_0_power_limit_uw 2>/dev/null || echo "0")

case "$gov" in
  performance)
    if [ "$pl1" -ge 45000000 ] 2>/dev/null; then
      echo "<span color='#FF3333'>GOD</span>"
    else
      echo "SPD"
    fi
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
