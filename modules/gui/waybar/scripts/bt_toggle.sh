#!/usr/bin/env bash
# Toggle bluetooth radio. Off = adapter powered down AND kernel radio blocked
# via rfkill (no scanning, advertising, or connections possible). On = rfkill
# unblock + power the adapter up. /dev/rfkill is user-writable via the systemd
# uaccess ACL for the active seat, so no sudo needed. bluetoothctl calls are
# wrapped in `timeout` because they hang when bluez has no controller. Read
# state from the hci* rfkill row, not tpacpi_bluetooth_sw.
#
# Refuse to power on unless networking is definitively enabled. Leaving
# airgap must be an explicit action via the NET module.
#
# This test is fail-closed on purpose: the old `= "disabled"` form let an
# unreachable NetworkManager (empty output) fall through to the power-on
# path, so bluetooth could come up while the NET module was reporting an
# airgap. Anything that is not a clear "enabled" now blocks the radio.
#
# A flag file signals bt_mode.sh to render yellow "BTH" while this script is
# running, since bluetoothctl + rfkill take a second or two.
if [ "$(timeout 3 nmcli -t networking 2>/dev/null)" != "enabled" ]; then
  rfkill block bluetooth 2>/dev/null || true
  timeout 2 bluetoothctl power off >/dev/null 2>&1 || true
  pkill -RTMIN+12 waybar 2>/dev/null || true
  exit 0
fi

flag="${XDG_RUNTIME_DIR:-/tmp}/waybar-bt-toggling"
trap 'rm -f "$flag"; pkill -RTMIN+12 waybar 2>/dev/null || true' EXIT
touch "$flag"
pkill -RTMIN+12 waybar 2>/dev/null || true

soft=$(rfkill list -o DEVICE,SOFT -n 2>/dev/null | awk '/^hci/ {print $2; exit}')
powered=$(timeout 1 bluetoothctl show 2>/dev/null | awk -F': ' '/Powered:/ {print $2; exit}')
if [ "$soft" = "unblocked" ] && [ "$powered" = "yes" ]; then
  timeout 2 bluetoothctl power off >/dev/null 2>&1 || true
  rfkill block bluetooth
else
  rfkill unblock bluetooth
  timeout 2 bluetoothctl power on >/dev/null 2>&1 || true
fi
