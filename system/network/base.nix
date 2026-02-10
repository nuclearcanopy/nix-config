{ ... }:

{
  services.resolved.enable = true;
  
  networking = {
    hostName = "kuraokami";

    networkmanager = {
      enable = true;

      # Ensure gigabit ethernet with forced 1000Mbps speed
      ensureProfiles.profiles = {
        "Wired connection 1" = {
          connection = {
            id = "Wired connection 1";
            type = "ethernet";
            interface-name = "enp4s0";
          };
          ethernet = {
            auto-negotiate = false;
            speed = 1000;
            duplex = "full";
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
