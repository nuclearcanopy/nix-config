#!/usr/bin/env bash
pct=$(df --output=pcent / | tail -n1 | tr -dc '0-9')
((pct > 99)) && pct=99
if ((pct > 90)); then
  printf "<span color='#B96B6B'>SSD %02d%%</span>\n" "$pct"
else
  printf 'SSD %02d%%\n' "$pct"
fi
