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
