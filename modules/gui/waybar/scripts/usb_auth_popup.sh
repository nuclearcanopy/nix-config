#!/usr/bin/env bash
# Hooked by `usbguard watch -e` (usbguard-auth-popup.service in
# modules/security/hardening-physical.nix). Runs once per USBGuard IPC
# event; only acts when a device's resolved policy just became "block"
# (same signal usbguard-notifier already keys its "blocked" notification
# off of). Prompts for the login password via the same SUDO_ASKPASS zenity
# dialog sudo uses, then allows the device for this boot only — identical
# scope to the manual Mod+Shift+u flow in usb_allow.sh.
set -euo pipefail

[[ "${USBGUARD_IPC_SIGNAL:-}" == "Device.PolicyChanged" ]] || exit 0
[[ "${USBGUARD_DEVICE_TARGET_NEW:-}" == "block" ]] || exit 0

NAME=$(grep -oP 'name "\K[^"]*' <<< "${USBGUARD_DEVICE_RULE:-}" || true)
NAME=${NAME:-unknown device}

notify-send "USB device blocked" "$NAME — enter your password to allow it"

# -k first: a warm sudo timestamp from an unrelated terminal command must
# not silently auto-approve a device with no prompt at all.
sudo -k
if sudo -A true 2>/dev/null; then
  if usbguard allow-device "${USBGUARD_DEVICE_ID:-}" 2>/dev/null; then
    notify-send "USB allowed" "$NAME"
  else
    notify-send "USB allow failed" "$NAME"
  fi
else
  notify-send "USB still blocked" "$NAME (cancelled or wrong password)"
fi
