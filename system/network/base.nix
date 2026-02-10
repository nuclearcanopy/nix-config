{ ... }:

{
  # DNS resolution with VPN leak protection
  services.resolved = {
    enable = true;
    # Disable DNS leak vectors
    llmnr = "false";
    extraConfig = ''
      MulticastDNS=no
      DNSSEC=no
      DNSOverTLS=no
      # Remove fallback DNS to prevent leaks when VPN is active
      FallbackDNS=
    '';
  };

  networking = {
    hostName = "kuraokami";

    networkmanager = {
      enable = true;

      # Prevent DNS leaks through NetworkManager
      dns = "systemd-resolved";

      # Force gigabit ethernet (1000Mbps full duplex, no auto-negotiation)
      # Commented out - let NetworkManager auto-configure to debug speed cap
      # ensureProfiles.profiles = {
      #   "Wired connection 1" = {
      #     connection = {
      #       id = "Wired connection 1";
      #       type = "ethernet";
      #       interface-name = "enp4s0";
      #       autoconnect = true;
      #     };
      #     ethernet = {
      #       speed = 1000;
      #       duplex = "full";
      #       auto-negotiate = false;
      #     };
      #     ipv4.method = "auto";
      #     ipv6.method = "auto";
      #   };
      # };
    };

    firewall = {
      enable = true;
      checkReversePath = false;

      # ProtonVPN WireGuard ports (per official support)
      allowedUDPPorts = [
        88 443 500 1224 4500 51820
      ];

      allowedTCPPorts = [
        443  # WireGuard TCP fallback
      ];
    };
  };
}
