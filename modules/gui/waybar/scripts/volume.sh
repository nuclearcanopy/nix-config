#!/usr/bin/env bash
# Volume indicator. Tracks wpctl's @DEFAULT_AUDIO_SINK@ and re-queries on
# pipewire/pulse events so switching the default output (e.g. plugging in
# headphones, swapping to a USB DAC) updates the bar immediately. Event-driven
# via `pactl subscribe`; no polling.

print_status() {
  local _ vol rest pct over
  read -r _ vol rest < <(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
  if [[ -z "$vol" ]]; then
    echo "VOL --"
    return
  fi
  if [[ "$rest" == *"MUTED"* ]]; then
    echo '<span color="#B96B6B">VOL 00%</span>'
    return
  fi
  # wpctl prints "Volume: X.XX" with two decimal digits.
  pct=$(( 10#${vol/./} ))
  if (( pct > 100 )); then
    over=$(( pct - 100 ))
    (( over > 99 )) && over=99
    printf '<span color="#B96B6B">VOL %02d%%</span>\n' "$over"
  else
    (( pct > 99 )) && pct=99
    printf 'VOL %02d%%\n' "$pct"
  fi
}

# On sway-session startup wireplumber's default sink can take a beat; retry up
# to ~6s so the first paint isn't a blank "VOL --".
for _ in $(seq 1 30); do
  out=$(print_status)
  [[ "$out" != "VOL --" ]] && break
  sleep 0.2
done
echo "$out"

# `sink` covers volume + mute changes; `server` covers default-sink swaps.
# pactl is from pipewire-pulse so this works against pipewire natively.
while true; do
  pactl subscribe 2>/dev/null | while read -r ev; do
    case "$ev" in
      *" sink"*|*" server"*) print_status ;;
    esac
  done
  sleep 1
done
