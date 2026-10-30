#!/usr/bin/env bash
gov=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "powersave")
no_turbo=$(cat /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || echo "0")

# Left-click  (next): lap → bal → spd → lap
# Right-click (prev): lap → spd → bal → lap
# Middle-click (mid): god, except from lap it enters sil (red LAP: lap limits
#   with the fan pinned off) and from sil it drops back to plain lap.
# Cycling out of sil with left/right needs no special case: those write a
# non-sil mode to the state file, which releases the fan (fan-silence.nix).
case "${1:-next}" in
  mid)
    if [ -d /run/fan-silence ]; then
      set-cpu-mode lap
    elif [ "$gov" = "powersave" ] && [ "$no_turbo" = "1" ]; then
      set-cpu-mode sil
    else
      set-cpu-mode god
    fi
    ;;
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
