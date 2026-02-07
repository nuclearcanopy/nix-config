{ ... }:

{
  services.resolved.enable = true;
  
  networking = {
    hostName = "kuraokami";

    networkmanager.enable = true;

    firewall = {
      enable = true;
      checkReversePath = false; 

      allowedUDPPorts = [
        51820
      ];
    };
  };
}
