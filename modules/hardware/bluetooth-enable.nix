{
  # Bluetooth userspace stack. Kernel modules (btusb/bluetooth) are loaded
  # because they're no longer in hardening-physical's blacklist, and the AX210
  # radio (8087:0032) is allowlisted in USBGuard. To kill bluetooth again:
  # flip enable=false here, re-add btusb/bluetooth to blacklistedKernelModules,
  # and drop the 8087:0032 USBGuard rule.
  nixos.modules.bluetooth-enable = {
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
    services.blueman.enable = true;
  };
}
