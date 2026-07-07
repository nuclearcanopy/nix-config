#!/usr/bin/env bash
# Waybar bluetooth state: "BTH" (default) when the hci radio is unblocked and
# the adapter is powered, red "BTH" otherwise (blocked, no adapter, or off).
# Ignore tpacpi_bluetooth_sw: on T480/Libreboot it reads hard-blocked
# persistently but the hci device itself is what matters. bluetoothctl is
# wrapped in `timeout` because it hangs when bluez has no controller.
state=$(rfkill list -o DEVICE,SOFT,HARD -n 2>/dev/null | awk '/^hci/ {print $2, $3; exit}')
soft=${state% *}
hard=${state#* }
powered=$(timeout 1 bluetoothctl show 2>/dev/null | awk -F': ' '/Powered:/ {print $2; exit}')
if [ "$soft" = "unblocked" ] && [ "$hard" = "unblocked" ] && [ "$powered" = "yes" ]; then
  echo "BTH"
else
  echo "<span color='#B96B6B'>BTH</span>"
fi
