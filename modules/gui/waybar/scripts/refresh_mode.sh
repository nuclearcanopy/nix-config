#!/usr/bin/env bash
# Waybar HDMI-A-2 refresh-rate indicator. Green "RFH" (#71A671) at 60Hz,
# default white "RFH" at 30Hz, dim "RFH" (#444) when the external monitor
# isn't connected. Companion to refresh_toggle.sh.
mode=$(swaymsg -t get_outputs -r 2>/dev/null | python3 -c '
import json, sys
outs = json.load(sys.stdin)
o = [o for o in outs if o["name"] == "HDMI-A-2"]
if not o or not o[0].get("active"):
    print("")
    raise SystemExit
m = o[0].get("current_mode") or {}
print(m.get("refresh", 0))
' 2>/dev/null)

if [ -z "$mode" ]; then
  echo "<span color='#444444'>RFH</span>"
elif [ "$mode" -ge 45000 ]; then
  echo "<span color='#71A671'>RFH</span>"
else
  echo "RFH"
fi
