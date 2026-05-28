{ config, pkgs, lib, ... }:

{
  networking.hostName = "homeserver";

  networking.networkmanager.enable = true;

  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "docker0" ];
    allowedTCPPorts = [
      1208  # ssh
      4533  # navidrome
      8080  # searxng
      8081  # filebrowser
      9000  # portainer
      8090  # mscd api
    ];
    allowedUDPPorts = [];
    checkReversePath = "loose";
  };

  services.resolved = {
    enable = true;
    dnssec = "allow-downgrade";
    dnsovertls = "opportunistic";
    llmnr = "false";
    extraConfig = ''
      MulticastDNS=no
    '';
  };

  services.mullvad-vpn.enable = true;

  systemd.services.mullvad-daemon.serviceConfig.TimeoutStopSec = 15;

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
      ${pkgs.mullvad}/bin/mullvad lan set allow
      ${pkgs.mullvad}/bin/mullvad connect
    '';
  };

  services.openssh = {
    enable = true;
    ports = [ 1208 ];
    settings = {
      PasswordAuthentication = false;
      PubkeyAuthentication = true;
      PermitRootLogin = "no";
      ListenAddress = "0.0.0.0";
    };
  };
}
