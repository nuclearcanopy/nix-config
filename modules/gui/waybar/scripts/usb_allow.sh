#!/usr/bin/env bash
# Pick a USBGuard-blocked device from a bemenu list and authorize it.
#
# Runs unprivileged: the user is in services.usbguard.IPCAllowedUsers
# (modules/security/hardening-physical.nix), so the IPC calls below need no
# sudo. The authorization lasts until reboot, because the ruleset is generated
# into the nix store and is immutable at runtime. To make a device permanent,
# add `allow id <vid>:<pid>` to that module and rebuild; the notification below
# prints the id so it can be copied straight in.
set -uo pipefail

BLOCKED=$(usbguard list-devices --blocked 2>/dev/null)

if [[ -z "$BLOCKED" ]]; then
  notify-send "USBGuard" "No blocked devices."
  exit 0
fi

# "17: block id 0951:1666 ... name \"DataTraveler\" ..." -> "17<TAB>0951:1666 DataTraveler"
CHOICE=$(
  echo "$BLOCKED" | sed -n 's/^\([0-9]\+\): *block *id *\([^ ]*\).*name "\([^"]*\)".*/\1\t\2  \3/p' \
    | bemenu "$@" -p "allow usb:"
) || exit 0

[[ -z "$CHOICE" ]] && exit 0

RULE_ID=${CHOICE%%$'\t'*}
LABEL=${CHOICE#*$'\t'}

if usbguard allow-device "$RULE_ID" 2>/dev/null; then
  notify-send "USB allowed (until reboot)" "$LABEL"
else
  notify-send -u critical "USBGuard" "Failed to allow device $RULE_ID"
fi
