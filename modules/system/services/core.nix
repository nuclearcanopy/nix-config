{ pkgs, ... }:

{
  security = {
    polkit.enable = true;
    protectKernelImage = true;
  };

  systemd.coredump.enable = false;

  services.udev.extraRules = ''
    # fix rtl8111 drops
    ACTION=="add", SUBSYSTEM=="net", ATTR{device/vendor}=="0x10ec", ATTR{device/device}=="0x8168", RUN+="${pkgs.bash}/bin/sh -c 'echo off > /sys/class/net/%k/device/power/control'"
  '';

  # Keep browser profiles in tmpfs (RAM); faster reads, fewer SSD writes.
  # Pairs with the firefox-preload prelauncher in home/programs/firefox.nix.
  services.psd = {
    enable = true;
    resyncTimer = "30min";
  };

  services = {
    logind.settings.Login.HandlePowerKey = "suspend";

    libinput.enable = true;

    flatpak.enable = true;

    avahi.enable = false;
  };
}
