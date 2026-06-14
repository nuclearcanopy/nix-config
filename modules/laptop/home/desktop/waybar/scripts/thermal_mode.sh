#!/usr/bin/env bash
{
  read -r gov      < /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
  read -r no_turbo < /sys/devices/system/cpu/intel_pstate/no_turbo
  read -r pl1      < /sys/devices/virtual/powercap/intel-rapl/intel-rapl:0/constraint_0_power_limit_uw
} 2>/dev/null
gov=${gov:-?}; no_turbo=${no_turbo:-0}; pl1=${pl1:-0}

case "$gov" in
  performance)
    if (( pl1 >= 45000000 )); then
      echo "<span color='#FF3333'>GOD</span>"
    else
      echo "SPD"
    fi ;;
  powersave)
    if [[ "$no_turbo" == "1" ]]; then
      echo "<span color='#B8A86A'>LAP</span>"
    else
      echo "BAL"
    fi ;;
  *) echo "???" ;;
esac
