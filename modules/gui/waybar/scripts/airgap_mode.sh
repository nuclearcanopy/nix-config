#!/usr/bin/env bash
# Yellow "NET" (#C6A857) while airgap_toggle.sh is mid-flip, otherwise
# default "NET" when networking is enabled, red "AIR" when airgapped, or
# red "ERR" when NetworkManager does not answer at all.
#
# The nmcli call is wrapped in `timeout` and matched exhaustively rather than
# compared against "enabled" alone. A NetworkManager stuck in the kernel
# (e.g. holding RTNL after a wifi device fails to resume from S3) stops
# serving D-Bus, so nmcli prints nothing; the old `!= enabled` test rendered
# that as red AIR, which read as "airgap armed itself" when connectivity was
# in fact never disabled.
flag="${XDG_RUNTIME_DIR:-/tmp}/waybar-airgap-toggling"
if [ -e "$flag" ]; then
  echo "<span color='#C6A857'>NET</span>"
  exit 0
fi
state=$(timeout 3 nmcli -t networking 2>/dev/null)
case "$state" in
  enabled)  echo "NET" ;;
  disabled) echo "<span color='#B96B6B'>AIR</span>" ;;
  *)        echo "<span color='#B96B6B'>ERR</span>" ;;
esac
