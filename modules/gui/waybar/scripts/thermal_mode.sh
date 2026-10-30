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
      echo "<span color='#B96B6B'>GOD</span>"
    else
      echo "SPD"
    fi ;;
  powersave)
    if [[ "$no_turbo" == "1" ]]; then
      # /run/fan-silence is fan-silence.service's RuntimeDirectory: present
      # only while the fan is pinned to level 0, i.e. the `sil` mode.
      if [[ -d /run/fan-silence ]]; then
        echo "<span color='#B96B6B'>LAP</span>"
      else
        echo "<span color='#B8A86A'>LAP</span>"
      fi
    else
      echo "BAL"
    fi ;;
  *) echo "???" ;;
esac
