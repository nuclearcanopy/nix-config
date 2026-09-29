# Single source of truth for two USB device ids repeated across several
# modules (udev rules, USBGuard allowlist, TLP autosuspend denylist, the
# post-resume re-authorize loop). Update here rather than grepping for the
# old id across modules/power/tlp.nix, modules/power/power-suspend.nix,
# modules/power/cpu-modes.nix, modules/security/hardening-physical.nix, and
# modules/gui/waybar/scripts/mouse_battery.sh (the last one is plain shell
# and can't import this file; its comment cross-references this one).
{
  logitechG502XReceiver = { vendor = "046d"; product = "c547"; };
  kindleScribe = { vendor = "1949"; product = "9981"; };
}
