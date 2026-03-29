#!/usr/bin/env bash
USED_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
FREE_KB=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
USED_GB=$(awk "BEGIN {printf \"%.1f\", ($USED_KB - $FREE_KB) / 1048576}")
printf "MEM %04.1fG\n" "$USED_GB"
