#!/usr/bin/env bash
brightness=$(brightnessctl get)
max=$(brightnessctl max)
pct=$(( brightness * 100 / max ))
echo "BRT ${pct}%"
