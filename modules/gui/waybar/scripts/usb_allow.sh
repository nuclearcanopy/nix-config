#!/usr/bin/env bash
# Pick a USBGuard-blocked device from a bemenu list and authorize it.
#
# Device listing is allowed by a read-only USBGuard IPC ACL. Authorizing a
# blocked device requires a fresh sudo password. The authorization lasts until
# reboot; for permanent trust, add `allow id <vid>:<pid>` to
# hardening-physical.nix and rebuild.
set -uo pipefail

source "$HOME/.config/theme-mode/bemenu.sh"

BLOCKED=$(usbguard list-devices --blocked 2>/dev/null)

if [[ -z "$BLOCKED" ]]; then
  notify-send "USBGuard" "No blocked devices."
  exit 0
fi

# "17: block id 0951:1666 ... name \"DataTraveler\" ..." -> "17<TAB>0951:1666 DataTraveler"
CHOICE=$(
  echo "$BLOCKED" | sed -n 's/^\([0-9]\+\): *block *id *\([^ ]*\).*name "\([^"]*\)".*/\1\t\2  \3/p' \
    | bemenu "${BEMENU_FLAGS[@]}" -p "allow usb:"
) || exit 0

[[ -z "$CHOICE" ]] && exit 0

RULE_ID=${CHOICE%%$'\t'*}
LABEL=${CHOICE#*$'\t'}

# Never rely on a warm sudo timestamp for a physical-device approval.
sudo -k
if sudo -A usbguard allow-device "$RULE_ID" 2>/dev/null; then
  notify-send "USB allowed (until reboot)" "$LABEL"
else
  notify-send -u critical "USBGuard" "Failed to allow device $RULE_ID"
fi
