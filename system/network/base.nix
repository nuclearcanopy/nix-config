{ ... }:

{
  # Mullvad VPN daemon
  services.mullvad-vpn.enable = true;

  # DNS resolution with VPN leak protection
  services.resolved = {
    enable = true;
    # Disable DNS leak vectors
    #llmnr = "false";
    #extraConfig = ''
    #  MulticastDNS=no
    #  DNSSEC=no
    #  DNSOverTLS=no
    #  # Remove fallback DNS to prevent leaks when VPN is active
    #  FallbackDNS=
    #'';
  };

  networking = {
    hostName = "kuraokami";

    networkmanager = {
      enable = true;

      # Prevent DNS leaks through NetworkManager
     # dns = "systemd-resolved";

      # Force gigabit ethernet with auto-negotiation enabled
      ensureProfiles.profiles = {
        "Wired connection 1" = {
          connection = {
            id = "Wired connection 1";
            type = "ethernet";
            interface-name = "enp4s0";
            autoconnect = true;
          };
          ethernet = {
            # Enable auto-negotiate to properly negotiate 1000Mbps
            auto-negotiate = true;
          };
          ipv4.method = "auto";
          ipv6.method = "auto";
        };
      };
    };

    firewall = {
      enable = true;
      checkReversePath = false;

      # Mullvad VPN WireGuard
      allowedUDPPorts = [
        51820  # WireGuard
      ];

      allowedTCPPorts = [
        443  # Mullvad API
      ];
    };
  };
}
