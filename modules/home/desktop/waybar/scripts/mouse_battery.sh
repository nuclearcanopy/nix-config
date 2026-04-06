#!/usr/bin/env bash

RAW=$(cat /sys/bus/hid/drivers/razermouse/0003:1532:*.*/charge_level 2>/dev/null | head -1)

if [[ -n "$RAW" ]]; then
    PERCENT=$((RAW * 100 / 255))
    ((PERCENT > 99)) && PERCENT=99
    printf "%02d" "$PERCENT"
else
    echo ""
fi
