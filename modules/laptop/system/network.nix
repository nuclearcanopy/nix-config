{ pkgs, ... }:

{
  imports = [ ../../system/network/base.nix ];

  services.mullvad-vpn.enable = true;

  # saves ~5.5s on boot; mullvad-autoconnect handles its own nm readiness check
  systemd.services.NetworkManager-wait-online.enable = false;

  systemd.services.mullvad-autoconnect = {
    description = "Auto-connect Mullvad VPN on boot";
    after = [ "graphical.target" "NetworkManager.service" "mullvad-daemon.service" ];
    wants = [ "NetworkManager.service" "mullvad-daemon.service" ];
    wantedBy = [ "graphical.target" ];
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
      ${pkgs.mullvad}/bin/mullvad tunnel set ipv6 on || true
      ${pkgs.mullvad}/bin/mullvad relay set location ro || true
      ${pkgs.mullvad}/bin/mullvad dns set default --block-ads --block-malware --block-trackers || true
      ${pkgs.mullvad}/bin/mullvad connect
    '';
  };

  networking = {
    hostName = "nidhoggr";
    networkmanager = {
      wifi.powersave = true;
      wifi.scanRandMacAddress = true;
    };
  };
}
