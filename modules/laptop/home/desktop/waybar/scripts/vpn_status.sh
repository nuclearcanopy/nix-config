#!/usr/bin/env bash
status=$(mullvad status 2>/dev/null | head -1)
if [ "$status" = "Connected" ]; then
  echo "VPN"
else
  echo "<span color='#B96B6B'>VPN</span>"
fi
