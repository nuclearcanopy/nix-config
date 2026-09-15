#!/usr/bin/env bash
# Mouse battery. Three sources, cheapest first:
#   1. openrazer sysfs        (kuraokami's DeathAdder V4 Pro)
#   2. hidpp_battery_0 sysfs  (any receiver the kernel's hid-logitech-hidpp knows)
#   3. solaar over hidraw     (nidhoggr: the G502 X Lightspeed's receiver,
#                              046d:c547, is in no kernel HID++ id table, binds
#                              hid-generic, and so never gets a power_supply
#                              node; see modules/hardware/logitech.nix)
# Source 3 forks python and takes ~1s, so it only runs when 1 and 2 miss.
RAW=""
for f in /sys/bus/hid/drivers/razermouse/0003:1532:*.*/charge_level; do
  [[ -r "$f" ]] || continue
  read -r RAW < "$f"
  { read -r CHARGING < "${f%/*}/charge_status"; } 2>/dev/null
  break
done

PERCENT=""
if [[ -n "$RAW" ]]; then
  PERCENT=$((RAW * 100 / 255))
  ((PERCENT > 99)) && PERCENT=99
else
  BAT=/sys/class/power_supply/hidpp_battery_0
  if [[ -r "$BAT/capacity" ]]; then
    read -r PERCENT < "$BAT/capacity"
    { read -r STATUS < "$BAT/status"; } 2>/dev/null
    [[ "$STATUS" == "Charging" ]] && CHARGING=1
  elif command -v solaar >/dev/null 2>&1; then
    # `solaar show` prints one "Battery: NN%, <status>." per device, twice per
    # device (once in the feature list, once in the summary); take the first.
    # It is chatty on stderr about GTK/Notify even for this CLI action.
    LINE=$(timeout 15 solaar show 2>/dev/null | grep -m1 -E 'Battery: *[0-9]+%')
    if [[ "$LINE" =~ ([0-9]+)% ]]; then
      PERCENT="${BASH_REMATCH[1]}"
      # HID++ BatteryStatus: RECHARGING and SLOW_RECHARGE both mean on-charge.
      # ALMOST_FULL/FULL do not; they are reported while discharging too.
      [[ "$LINE" == *RECHARG* || "$LINE" == *recharg* ]] && CHARGING=1
    fi
  fi
fi

# No source answered: no mouse paired, receiver unplugged, or device asleep.
[[ -n "$PERCENT" ]] || { echo "MSE --%"; exit 0; }

if [[ "$CHARGING" == "1" ]]; then
  printf 'MSE CHG %02d%%\n' "$PERCENT"
elif ((PERCENT <= 10)); then
  printf "<span color='#B96B6B'>MSE %02d%%</span>\n" "$PERCENT"
elif ((PERCENT <= 25)); then
  printf "<span color='#e5c07b'>MSE %02d%%</span>\n" "$PERCENT"
else
  printf 'MSE %02d%%\n' "$PERCENT"
fi
