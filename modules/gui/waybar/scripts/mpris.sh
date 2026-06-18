#!/usr/bin/env bash
line=$(playerctl metadata --format '{{status}}|{{artist}}' 2>/dev/null)
[[ -z "$line" ]] && exit 0

status="${line%%|*}"
artist="${line#*|}"

if [[ -n "$artist" && "$artist" != "$status" ]]; then
  out="[${status}] ${artist}"
else
  out="[${status}]"
fi
out="${out^^}"
echo "${out:0:50}"
