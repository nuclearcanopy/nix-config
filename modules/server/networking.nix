{ config, pkgs, lib, ... }:

{
  networking.hostName = "homeserver";

  networking.networkmanager.enable = true;

  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "docker0" "tailscale0" ];
    allowedTCPPorts = [
      1208  # ssh
      4533  # navidrome
      8080  # searxng
      8081  # filebrowser
      9000  # portainer
      8090  # mscd api
    ];
    allowedUDPPorts = [
      41641  # tailscale
    ];
    checkReversePath = "loose";
    # mark packets forwarded from tailscale0 so policy routing sends them via physical iface
    extraCommands = ''
      iptables -t mangle -C FORWARD -i tailscale0 -j MARK --set-mark 0x1 2>/dev/null || \
        iptables -t mangle -A FORWARD -i tailscale0 -j MARK --set-mark 0x1
    '';
  };

  networking.iproute2.rttablesExtraConfig = ''
    100 bypass-vpn
  '';

  # capture the physical default route before mullvad-autoconnect replaces it,
  # then install a policy rule so marked (tailscale-forwarded) packets bypass the vpn tunnel
  systemd.services.tailscale-exit-routing = {
    description = "Policy routing bypass for Tailscale exit node";
    after = [ "network-online.target" ];
    before = [ "mullvad-autoconnect.service" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = [ pkgs.iproute2 pkgs.gawk ];
    script = ''
      GW=$(ip route show default | awk 'NR==1{print $3; exit}')
      DEV=$(ip route show default | awk 'NR==1{print $5; exit}')
      ip route replace default via $GW dev $DEV table 100
      ip rule add fwmark 0x1 lookup 100 priority 100 2>/dev/null || true
    '';
  };

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
  };

  services.mullvad-vpn.enable = true;

  systemd.services.mullvad-daemon.serviceConfig.TimeoutStopSec = 15;

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
