{ ... }:

{
  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNSSEC = "true";
      DNSOverTLS = "opportunistic";
      LLMNR = "false";
      MulticastDNS = "no";
    };
  };

  networking = {
    networkmanager = {
      enable = true;

      ensureProfiles.profiles = {
        "Wired connection 1" = {
          connection = {
            id = "Wired connection 1";
            type = "ethernet";
            autoconnect = true;
          };
          ethernet = {
            auto-negotiate = true;
          };
          ipv4.method = "auto";
          ipv6.method = "auto";
        };
      };
    };

    firewall = {
      enable = true;

      allowedUDPPorts = [
        51820  # WireGuard
      ];
      allowedTCPPorts = [
        10206  # Local webdev server
      ];

    };
  };
}
