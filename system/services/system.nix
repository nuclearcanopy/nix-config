{ pkgs, ... }:

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
    ACTION=="add", SUBSYSTEM=="net", ATTR{device/vendor}=="0x10ec", ATTR{device/device}=="0x8168", RUN+="${pkgs.bash}/bin/sh -c 'echo off > /sys/class/net/%k/device/power/control'"
  '';

  # services
  services = {
    # logind power button behavior
    logind.settings.Login.HandlePowerKey = "suspend";

    # xserver
    xserver = {
      displayManager.lightdm.enable = false;
    };

    # input
    libinput.enable = true;

    # dbus
    dbus.enable = true;

    # disable zeroconf/mDNS
    avahi.enable = false;
  };
}
