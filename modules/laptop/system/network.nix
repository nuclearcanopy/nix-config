{ pkgs, ... }:

{
  services.mullvad-vpn.enable = true;
  systemd.services.mullvad-autoconnect = {
    description = "Auto-connect Mullvad VPN on boot (laptop)";
    after = [ "network-online.target" "mullvad-daemon.service" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      sleep 2
      ${pkgs.mullvad}/bin/mullvad lan set allow
      ${pkgs.mullvad}/bin/mullvad connect
    '';
  };
  services.resolved = {
    enable = true;
    dnssec = "true";
    dnsovertls = "true";
    llmnr = "false";
    extraConfig = ''
      MulticastDNS=no
    '';
  };

  networking = {
    hostName = "nidhoggr";

    networkmanager = {
      enable = true;
      # WiFi power saving for battery life
      wifi.powersave = true;
      wifi.scanRandMacAddress = true;
      # WiFi is managed interactively via nmtui/nmcli or the NM applet.
      # Wired auto-connects below; wireless profiles added post-install.
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
