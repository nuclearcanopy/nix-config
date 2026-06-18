#!/usr/bin/env bash
state=$(nmcli -t networking 2>/dev/null)
if [ "$state" = "enabled" ]; then
  nmcli radio all off
  nmcli networking off
  bluetoothctl power off >/dev/null 2>&1 || true
else
  nmcli networking on
  nmcli radio all on
fi
pkill -RTMIN+11 waybar 2>/dev/null || true
