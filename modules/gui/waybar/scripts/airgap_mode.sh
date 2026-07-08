#!/usr/bin/env bash
# Yellow "NET" (#C6A857) while airgap_toggle.sh is mid-flip, otherwise
# default "NET" when networking is enabled or red "AIR" when airgapped.
flag="${XDG_RUNTIME_DIR:-/tmp}/waybar-airgap-toggling"
if [ -e "$flag" ]; then
  echo "<span color='#C6A857'>NET</span>"
  exit 0
fi
state=$(nmcli -t networking 2>/dev/null)
if [ "$state" = "enabled" ]; then
  echo "NET"
else
  echo "<span color='#B96B6B'>AIR</span>"
fi
