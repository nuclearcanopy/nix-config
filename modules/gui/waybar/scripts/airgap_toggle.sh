#!/usr/bin/env bash
# Toggle airgap. On (NET) = networking + all radios enabled. Off (AIR) =
# nmcli networking off, all radios off, bluetooth adapter powered down and
# rfkill-blocked so bt_toggle.sh cannot bring it back up.
#
# A flag file signals airgap_mode.sh to render yellow "NET" while this script
# is running, since nmcli calls take a moment.
flag="${XDG_RUNTIME_DIR:-/tmp}/waybar-airgap-toggling"
trap 'rm -f "$flag"; pkill -RTMIN+11 waybar 2>/dev/null || true; pkill -RTMIN+12 waybar 2>/dev/null || true' EXIT
touch "$flag"
pkill -RTMIN+11 waybar 2>/dev/null || true

state=$(nmcli -t networking 2>/dev/null)
if [ "$state" = "enabled" ]; then
  nmcli radio all off
  nmcli networking off
  bluetoothctl power off >/dev/null 2>&1 || true
  rfkill block bluetooth
else
  nmcli networking on
  nmcli radio all on
fi
