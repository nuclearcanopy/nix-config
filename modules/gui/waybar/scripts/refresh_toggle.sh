#!/usr/bin/env bash
# Toggle HDMI-A-2 between 30Hz and 60Hz at its current resolution. No-op
# when the display isn't connected. sway picks the closest advertised mode
# for the requested WxH@RHz; the monitor advertises both 30 and 60 at
# common resolutions (1080p, 720p) so the swap always resolves cleanly.
read -r w h r < <(swaymsg -t get_outputs -r 2>/dev/null | python3 -c '
import json, sys
outs = json.load(sys.stdin)
o = [o for o in outs if o["name"] == "HDMI-A-2"]
if not o or not o[0].get("active"):
    raise SystemExit
m = o[0].get("current_mode") or {}
print(m.get("width", 0), m.get("height", 0), m.get("refresh", 0))
')

[ -z "${w:-}" ] && exit 0

if [ "$r" -ge 45000 ]; then
  new=30
else
  new=60
fi

swaymsg output HDMI-A-2 mode "${w}x${h}@${new}Hz" >/dev/null 2>&1
pkill -RTMIN+13 waybar 2>/dev/null || true
