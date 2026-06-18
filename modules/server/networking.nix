{
  # Homeserver networking: firewall (with docker trusted + service ports),
  # resolved, mullvad + autoconnect, openssh on 1208 with pubkey-only +
  # restrictions (no root, no agent/tcp forwarding, X11 off).
  nixos.modules.server-networking = { pkgs, username, ... }: {
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
      settings.Resolve = {
        DNSSEC = "allow-downgrade";
        DNSOverTLS = "opportunistic";
        LLMNR = "false";
        MulticastDNS = "no";
      };
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
        TimeoutStartSec = 180;
      };
      script = ''
        set -euo pipefail

        i=0
        until ${pkgs.mullvad}/bin/mullvad status >/dev/null 2>&1; do
          i=$((i + 1))
          if [ "$i" -ge 60 ]; then
            echo "mullvad-autoconnect: daemon not ready after 60s" >&2
            exit 1
          fi
          sleep 1
        done

        ${pkgs.mullvad}/bin/mullvad lan set allow || true
        ${pkgs.mullvad}/bin/mullvad connect
      '';
    };

    services.openssh = {
      enable = true;
      ports = [ 1208 ];
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitEmptyPasswords = false;
        PubkeyAuthentication = true;
        AuthenticationMethods = "publickey";
        PermitRootLogin = "no";
        AllowUsers = username;
        ListenAddress = "0.0.0.0";
        MaxAuthTries = 3;
        LoginGraceTime = 20;
        X11Forwarding = false;
        AllowAgentForwarding = false;
        AllowTcpForwarding = false;
        ClientAliveInterval = 300;
        ClientAliveCountMax = 2;
      };
    };
  };
}
