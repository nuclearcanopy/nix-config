{
  # Bluetooth fully off: userspace stack disabled here, kernel modules
  # blacklisted in the hardening-laptop bucket, USBGuard blocks BT radios
  # on insert. To re-enable: also drop btusb/bluetooth from hardening-laptop's
  # blacklistedKernelModules and add `allow id 8087:0032` to USBGuard rules.
  nixos.modules.bluetooth-disable = {
    hardware.bluetooth.enable = false;
    services.blueman.enable = false;
  };
}
