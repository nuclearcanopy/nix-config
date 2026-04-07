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
  };

  services.mullvad-vpn.enable = true;

  services.openssh = {
    enable = true;
    ports = [ 1208 ];
    settings = {
      PasswordAuthentication = true;
      PubkeyAuthentication = true;
      PermitRootLogin = "no";
      ListenAddress = "0.0.0.0";
    };
  };

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
      # wait for daemon
      sleep 2
      ${pkgs.mullvad}/bin/mullvad lan set allow
      ${pkgs.mullvad}/bin/mullvad connect
    '';
  };
}
