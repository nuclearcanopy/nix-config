{ ... }:

{
  # hostname
  networking = {
    hostName = "kuraokami";

  # network manager
    networkmanager.enable = true;

  # dns
    services.resolved.enable = true;

  # firewall
    firewall = {
      enable = true;
      checkReversePath = false; 

      allowedUDPPorts = [
        51820
      ];
    };
  };
}
