#!/usr/bin/env bash
# Toggle airgap. On (NET) = networking + all radios enabled. Off (AIR) =
# nmcli networking off, all radios off, bluetooth adapter powered down and
# rfkill-blocked so bt_toggle.sh cannot bring it back up.
#
# A flag file signals airgap_mode.sh to render yellow "NET" while this script
# is running, since nmcli calls take a moment.
#
# Every nmcli call is wrapped in `timeout`. If NetworkManager is wedged it
# never answers, and an unbounded call would block here holding the flag file,
# pinning the module yellow forever while accomplishing nothing. Read the
# state before arming the flag and bail on anything but a definite
# enabled/disabled, so a press against a dead NM leaves the module showing
# ERR instead of silently issuing a command that cannot land.
state=$(timeout 3 nmcli -t networking 2>/dev/null)
if [ "$state" != "enabled" ] && [ "$state" != "disabled" ]; then
  pkill -RTMIN+11 waybar 2>/dev/null || true
  exit 1
fi

flag="${XDG_RUNTIME_DIR:-/tmp}/waybar-airgap-toggling"
trap 'rm -f "$flag"; pkill -RTMIN+11 waybar 2>/dev/null || true; pkill -RTMIN+12 waybar 2>/dev/null || true' EXIT
touch "$flag"
pkill -RTMIN+11 waybar 2>/dev/null || true

if [ "$state" = "enabled" ]; then
  timeout 10 nmcli radio all off
  timeout 10 nmcli networking off
  timeout 2 bluetoothctl power off >/dev/null 2>&1 || true
  rfkill block bluetooth
else
  timeout 10 nmcli networking on
  timeout 10 nmcli radio all on
fi
