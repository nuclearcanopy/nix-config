{ pkgs, ... }:

{
  security = {
    polkit.enable = true;
    protectKernelImage = true;
  };

  systemd = {
    services.display-manager.enable = false;
    coredump.enable = false;
  };

  services.udev.extraRules = ''
    # fix rtl8111 drops
    ACTION=="add", SUBSYSTEM=="net", ATTR{device/vendor}=="0x10ec", ATTR{device/device}=="0x8168", RUN+="${pkgs.bash}/bin/sh -c 'echo off > /sys/class/net/%k/device/power/control'"
  '';

  services = {
    logind.settings.Login.HandlePowerKey = "suspend";

    xserver = {
      displayManager.lightdm.enable = false;
    };

    libinput.enable = true;

    dbus.enable = true;

    avahi.enable = false;
  };
}
