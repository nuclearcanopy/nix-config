#!/usr/bin/env bash
# Retry briefly: when waybar is started by sway-session.target, wireplumber's
# default sink can take a beat to settle. interval=once means a silent first
# failure leaves the module blank until the next signal, so loop up to ~6s.
for _ in $(seq 1 30); do
  read -r _ vol rest < <(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
  [[ -n "$vol" ]] && break
  sleep 0.2
done

if [[ -z "$vol" ]]; then
  echo "VOL --"
  exit 0
fi

if [[ "$rest" == *"MUTED"* ]]; then
  echo '<span color="#B96B6B">VOL 00%</span>'
else
  pct=$(( 10#${vol/./} ))   # "0.45" -> 45
  ((pct > 99)) && pct=99
  printf 'VOL %02d%%\n' "$pct"
fi
