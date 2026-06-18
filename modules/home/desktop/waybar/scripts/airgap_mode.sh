#!/usr/bin/env bash
state=$(nmcli -t networking 2>/dev/null)
if [ "$state" = "enabled" ]; then
  echo "NET"
else
  echo "<span color='#B96B6B'>AIR</span>"
fi
