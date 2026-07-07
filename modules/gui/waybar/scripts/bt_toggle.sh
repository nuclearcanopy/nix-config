#!/usr/bin/env bash
# Toggle bluetooth radio. Off = adapter powered down AND kernel radio blocked
# via rfkill (no scanning, advertising, or connections possible). On = rfkill
# unblock + power the adapter up. /dev/rfkill is user-writable via the systemd
# uaccess ACL for the active seat, so no sudo needed. bluetoothctl calls are
# wrapped in `timeout` because they hang when bluez has no controller. Read
# state from the hci* rfkill row, not tpacpi_bluetooth_sw.
soft=$(rfkill list -o DEVICE,SOFT -n 2>/dev/null | awk '/^hci/ {print $2; exit}')
powered=$(timeout 1 bluetoothctl show 2>/dev/null | awk -F': ' '/Powered:/ {print $2; exit}')
if [ "$soft" = "unblocked" ] && [ "$powered" = "yes" ]; then
  timeout 2 bluetoothctl power off >/dev/null 2>&1 || true
  rfkill block bluetooth
else
  rfkill unblock bluetooth
  timeout 2 bluetoothctl power on >/dev/null 2>&1 || true
fi
pkill -RTMIN+12 waybar 2>/dev/null || true
