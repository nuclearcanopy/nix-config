{ ... }:

{
  services.resolved.enable = true;
  
  networking = {
    hostName = "kuraokami";

    networkmanager = {
      enable = true;

      # Declarative wired ethernet profile with auto-negotiation
      ensureProfiles.profiles = {
        "Wired connection 1" = {
          connection = {
            id = "Wired connection 1";
            type = "ethernet";
            interface-name = "enp4s0";
            autoconnect = true;
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
