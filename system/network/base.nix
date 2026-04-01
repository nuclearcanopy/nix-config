{ ... }:

{
  services.mullvad-vpn.enable = true;
  services.resolved.enable = true;

  networking = {
    hostName = "kuraokami";

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
      checkReversePath = false;  # Required for Mullvad VPN

      allowedUDPPorts = [
        51820  # WireGuard (Mullvad)
      ];
      allowedTCPPorts = [
        10206  # Local webdev server
      ];
    };
  };
}
