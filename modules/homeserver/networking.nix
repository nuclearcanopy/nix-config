{ config, pkgs, lib, ... }:

{
  # Hostname
  networking.hostName = "homeserver";

  # NetworkManager
  networking.networkmanager.enable = true;

  # Firewall
  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "docker0" ];
    allowedTCPPorts = [
      1208   # SSH
      4533   # Navidrome
      8080   # SearXNG
      8081   # FileBrowser
      9000   # Portainer
      8090   # MSCD API
    ];
    allowedUDPPorts = [];
  };

  # Mullvad VPN
  services.mullvad-vpn.enable = true;

  # SSH configuration
  services.openssh = {
    enable = true;
    ports = [ 1208 ];
    settings = {
      PasswordAuthentication = true;  # Enabled for password auth
      PubkeyAuthentication = true;
      PermitRootLogin = "no";
      ListenAddress = "0.0.0.0";
    };
  };

  # Systemd service for Mullvad auto-connect
  systemd.services.mullvad-autoconnect = {
    description = "Auto-connect Mullvad VPN on boot";
    after = [ "network-online.target" "mullvad-daemon.service" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      # Wait for daemon to be fully ready
      sleep 2
      ${pkgs.mullvad}/bin/mullvad lan set allow
      ${pkgs.mullvad}/bin/mullvad connect
    '';
  };
}
