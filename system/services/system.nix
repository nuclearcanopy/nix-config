{ ... }:

{
  # security
  security = {
    polkit.enable = true;
    protectKernelImage = true;
  };

  # systemd
  systemd = {
    services.display-manager.enable = false;
    coredump.enable = false;
  };

  # udev rules
  services.udev.extraRules = ''
    # Disable power management for RTL8111 ethernet (prevents random disconnects)
    ACTION=="add", SUBSYSTEM=="net", KERNEL=="enp4s0", RUN+="/run/current-system/sw/bin/sh -c 'echo off > /sys/class/net/enp4s0/device/power/control'"
  '';

  # services
  services = {
    # xserver
    xserver = {
      enable = true;
      displayManager.lightdm.enable = false;
    };

    # input
    libinput.enable = true;

    # dbus
    dbus.enable = true;
  };
}
