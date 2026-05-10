#!/usr/bin/env bash
# Mouse battery: tries Razer (openrazer) then Logitech HID++ (hidpp_battery_0)

RAW=$(cat /sys/bus/hid/drivers/razermouse/0003:1532:*.*/charge_level 2>/dev/null | head -1)
if [[ -n "$RAW" ]]; then
  PERCENT=$((RAW * 100 / 255))
  ((PERCENT > 99)) && PERCENT=99
  CHARGING=$(cat /sys/bus/hid/drivers/razermouse/0003:1532:*.*/charge_status 2>/dev/null | head -1)
else
  BAT=/sys/class/power_supply/hidpp_battery_0
  PERCENT=$(cat "$BAT/capacity" 2>/dev/null)
  [[ -n "$PERCENT" ]] || { echo "MSE --%"; exit 0; }
  STATUS=$(cat "$BAT/status" 2>/dev/null)
  [[ "$STATUS" == "Charging" ]] && CHARGING=1
fi

if [[ "$CHARGING" == "1" ]]; then
  printf "MSE CHG %02d%%\n" "$PERCENT"
elif ((PERCENT <= 10)); then
  printf "<span color='#B96B6B'>MSE %02d%%</span>\n" "$PERCENT"
elif ((PERCENT <= 25)); then
  printf "<span color='#e5c07b'>MSE %02d%%</span>\n" "$PERCENT"
else
  printf "MSE %02d%%\n" "$PERCENT"
fi
