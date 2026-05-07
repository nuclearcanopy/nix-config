#!/usr/bin/env bash
brightness=$(brightnessctl get)
max=$(brightnessctl max)
pct=$(( brightness * 100 / max ))
[ "$pct" -gt 99 ] && pct=99
echo "BRT ${pct}%"
