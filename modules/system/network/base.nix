{ pkgs, ... }:

{
  services.mullvad-vpn.enable = true;

  systemd.services.mullvad-autoconnect = {
    description = "Auto-connect Mullvad VPN on boot";
    after = [ "NetworkManager.service" "mullvad-daemon.service" ];
    wants = [ "NetworkManager.service" "mullvad-daemon.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      TimeoutStartSec = 180;
    };
    script = ''
      set -euo pipefail

      # Wait for a configured link (best-effort; Mullvad can still connect later).
      ${pkgs.networkmanager}/bin/nm-online -s -q -t 30 || true

      # Wait for daemon responsiveness.
      i=0
      until ${pkgs.mullvad}/bin/mullvad status >/dev/null 2>&1; do
        i=$((i + 1))
        if [ "$i" -ge 60 ]; then
          echo "mullvad-autoconnect: mullvad daemon not ready after 60s" >&2
          exit 1
        fi
        sleep 1
      done

      ${pkgs.mullvad}/bin/mullvad lan set allow || true
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
