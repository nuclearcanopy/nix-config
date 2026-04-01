#!/usr/bin/env bash
VOL=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)

if [[ "$VOL" == *"MUTED"* ]]; then
  echo '<span color="#B96B6B">VOL 00%</span>'
else
  VOL=$(echo "$VOL" | awk '{printf "%.0f", $2 * 100}')
  ((VOL > 99)) && VOL=99
  printf "VOL %02d%%\n" "$VOL"
fi
