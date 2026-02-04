{ ... }:

{
  # hostname
  networking.hostName = "kuraokami";

  # network manager
  networking.networkmanager.enable = true;

  # dns
  services.resolved.enable = true;

  # firewall
  networking.firewall = {
    enable = true;
    checkReversePath = false;  # wireguard
  };
}
