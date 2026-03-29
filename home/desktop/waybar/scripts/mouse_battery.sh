#!/usr/bin/env bash

RAW=$(cat /sys/bus/hid/drivers/razermouse/0003:1532:00B7.*/charge_level 2>/dev/null | head -1)

if [[ -n "$RAW" ]]; then
    echo $((RAW * 100 / 255))
else
    echo ""
fi
