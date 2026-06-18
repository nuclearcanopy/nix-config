#!/usr/bin/env bash
for b in /sys/class/backlight/*; do
  read -r cur < "$b/brightness" 2>/dev/null
  read -r max < "$b/max_brightness" 2>/dev/null
  [[ -n "$cur" && -n "$max" && "$max" -gt 0 ]] || continue
  pct=$(( cur * 100 / max ))
  ((pct > 99)) && pct=99
  printf 'BRT %d%%\n' "$pct"
  exit 0
done
echo "BRT --%"
