#!/usr/bin/env bash
# Waybar bluetooth state: green "BTH" (#71A671) when the hci radio is unblocked
# and the adapter is powered, default white "BTH" otherwise (blocked, no
# adapter, or off). Yellow "BTH" (#C6A857) while bt_toggle.sh is mid-flip.
# Ignore tpacpi_bluetooth_sw: on T480/Libreboot it reads hard-blocked
# persistently but the hci device itself is what matters. bluetoothctl is
# wrapped in `timeout` because it hangs when bluez has no controller.
flag="${XDG_RUNTIME_DIR:-/tmp}/waybar-bt-toggling"
if [ -e "$flag" ]; then
  echo "<span color='#C6A857'>BTH</span>"
  exit 0
fi
state=$(rfkill list -o DEVICE,SOFT,HARD -n 2>/dev/null | awk '/^hci/ {print $2, $3; exit}')
soft=${state% *}
hard=${state#* }
powered=$(timeout 1 bluetoothctl show 2>/dev/null | awk -F': ' '/Powered:/ {print $2; exit}')
if [ "$soft" = "unblocked" ] && [ "$hard" = "unblocked" ] && [ "$powered" = "yes" ]; then
  echo "<span color='#71A671'>BTH</span>"
else
  echo "BTH"
fi
