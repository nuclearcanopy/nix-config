#!/usr/bin/env bash
TEMP=0
for hwmon in /sys/class/hwmon/hwmon*; do
  { read -r name < "$hwmon/name"; } 2>/dev/null
  if [[ "$name" == "k10temp" || "$name" == "coretemp" ]]; then
    { read -r TEMP < "$hwmon/temp1_input"; } 2>/dev/null
    break
  fi
done
TEMP=$((TEMP / 1000))

# /proc/stat's first line is cumulative since boot, so reading it once gives
# the lifetime average, not current load: it sat at 20% whether idle or with
# three cores pinned. Keep the previous sample and report the delta over the
# module's interval instead.
STATE="${XDG_RUNTIME_DIR:-/tmp}/waybar-cpu-stat"

sample() {
  local _ u n s i io irq sirq rest
  read -r _ u n s i io irq sirq rest < /proc/stat
  SAMPLE_BUSY=$((u + n + s + io + irq + sirq))
  SAMPLE_TOTAL=$((SAMPLE_BUSY + i))
}

sample
busy=$SAMPLE_BUSY total=$SAMPLE_TOTAL

prev_busy=0 prev_total=0
if [[ -r "$STATE" ]]; then
  read -r prev_busy prev_total < "$STATE" 2>/dev/null || true
fi
printf '%s %s\n' "$busy" "$total" > "$STATE"

db=$((busy - prev_busy))
dt=$((total - prev_total))

# No usable previous sample (first run after boot, or the counters moved
# backwards): take a short live window rather than printing a bogus number.
if (( dt <= 0 || db < 0 )); then
  sample
  b0=$SAMPLE_BUSY t0=$SAMPLE_TOTAL
  sleep 0.2
  sample
  db=$((SAMPLE_BUSY - b0))
  dt=$((SAMPLE_TOTAL - t0))
fi

USAGE=0
(( dt > 0 )) && USAGE=$(( db * 100 / dt ))
(( USAGE < 0 )) && USAGE=0
(( USAGE > 99 )) && USAGE=99
printf 'CPU %02d° %02d%%\n' "$TEMP" "$USAGE"
