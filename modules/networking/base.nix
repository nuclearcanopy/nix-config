{
  # systemd-resolved (DNSSEC downgrade-friendly + opportunistic DoT) +
  # NetworkManager + firewall. DNSSEC is "allow-downgrade" so captive portals
  # (hotel/airport wifi that hijacks DNS to redirect the browser) can complete
  # the login flow; real DNSSEC is still enforced against upstreams that support
  # it. Wired ethernet profile is declared here for kuraokami's default
  # connection; nidhoggr has its own MAC-randomized base in laptop-network.
  nixos.modules.networking-base = {
    services.resolved = {
      enable = true;
      settings.Resolve = {
        DNSSEC = "allow-downgrade";
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
  };
}
