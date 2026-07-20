#!/usr/bin/env bash
# Microphone indicator. Tracks wpctl's @DEFAULT_AUDIO_SOURCE@ and re-queries on
# pipewire/pulse source events so muting or switching the default input updates
# the bar immediately. Event-driven via `pactl subscribe`; no polling.
#
# Replaces waybar's builtin wireplumber module, which races on EasyEffects'
# virtual source node at sway-session startup and spams "Object 'N' not found".

print_status() {
  local out
  out=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null)
  if [[ "$out" == *"MUTED"* ]]; then
    echo '<span color="#B96B6B">MTD</span>'
  else
    echo "MIC"
  fi
}

# On sway-session startup wireplumber's default source can take a beat; wait up
# to ~6s for wpctl to answer so the first paint reflects the real mute state.
for _ in $(seq 1 30); do
  wpctl get-volume @DEFAULT_AUDIO_SOURCE@ &>/dev/null && break
  sleep 0.2
done
print_status

# `source` covers mute/volume changes; `server` covers default-source swaps.
# pactl is from pipewire-pulse so this works against pipewire natively.
while true; do
  pactl subscribe 2>/dev/null | while read -r ev; do
    case "$ev" in
      *" source"*|*" server"*) print_status ;;
    esac
  done
  sleep 1
done
