{ ... }:

{
  services.resolved.enable = true;
  
  networking = {
    hostName = "kuraokami";

    networkmanager = {
      enable = true;

      # Force gigabit ethernet (1000Mbps full duplex, no auto-negotiation)
      ensureProfiles.profiles = {
        "Wired connection 1" = {
          connection = {
            id = "Wired connection 1";
            type = "ethernet";
            interface-name = "enp4s0";
            autoconnect = true;
          };
          ethernet = {
            speed = 1000;
            duplex = "full";
            auto-negotiate = false;
          };
          ipv4.method = "auto";
          ipv6.method = "auto";
        };
      };
    };

    firewall = {
      enable = true;
      checkReversePath = false;

      allowedUDPPorts = [
        51820
      ];
    };
  };
}
