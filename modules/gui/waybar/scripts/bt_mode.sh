#!/usr/bin/env bash
state=$(bluetoothctl show 2>/dev/null | awk '/Powered:/ {print $2; exit}')
if [ "$state" = "yes" ]; then
  echo "BTH"
else
  echo "<span color='#B96B6B'>BTH</span>"
fi
