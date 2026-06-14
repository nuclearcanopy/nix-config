#!/usr/bin/env bash
read -r _ vol rest < <(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)

if [[ "$rest" == *"MUTED"* ]]; then
  echo '<span color="#B96B6B">VOL 00%</span>'
else
  pct=$(( 10#${vol/./} ))   # "0.45" -> 45
  ((pct > 99)) && pct=99
  printf 'VOL %02d%%\n' "$pct"
fi
