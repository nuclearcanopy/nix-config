{ ... }:

# Bluetooth is fully off on this laptop.
# - Userspace stack (bluez, blueman) disabled.
# - btusb/bluetooth kernel modules blacklisted in hardening.nix, so the M.2
#   BT radio (Intel 8087:0032) never gets bound.
# - USBGuard's block-by-default policy also blocks it on insert.
# To re-enable: flip these to true, drop btusb/bluetooth from
# hardening.nix:blacklistedKernelModules, and add `allow id 8087:0032` to
# the USBGuard rules.
{
  hardware.bluetooth.enable = false;
  services.blueman.enable = false;
}
