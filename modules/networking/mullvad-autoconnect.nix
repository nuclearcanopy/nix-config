{
  # Shared Mullvad autoconnect service.
  # Defaults wrapped in mkDefault so hosts can override the start trigger
  # without mkForce. Laptop overrides wantedBy/wants/after to defer
  # autoconnect to graphical.target (post-login).
  nixos.modules.mullvad-autoconnect = { lib, pkgs, ... }: {
    services.mullvad-vpn.enable = true;

    systemd.services.mullvad-autoconnect = {
      description = "Auto-connect Mullvad VPN on boot";
      after = lib.mkDefault [ "NetworkManager.service" "mullvad-daemon.service" ];
      wants = lib.mkDefault [ "NetworkManager.service" ];
      wantedBy = lib.mkDefault [ "mullvad-daemon.service" ];
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

        # Wait for NM to report full internet reachability before bringing the
        # tunnel up. On a captive portal ("portal"/"limited") the tunnel can't
        # establish and would just wedge DNS/HTTP behind Mullvad, blocking the
        # portal login page. The nm-dispatcher-mullvad hook (laptop) will
        # connect once the portal is cleared.
        i=0
        while [ "$i" -lt 20 ]; do
          conn="$(${pkgs.networkmanager}/bin/nmcli -t networking connectivity check 2>/dev/null || echo unknown)"
          case "$conn" in
            full)
              exec ${pkgs.mullvad}/bin/mullvad connect
              ;;
            portal|limited)
              echo "mullvad-autoconnect: captive portal detected ($conn); leaving tunnel down" >&2
              exit 0
              ;;
          esac
          i=$((i + 1))
          sleep 1
        done

        # Fall through: connectivity never became authoritative, try anyway.
        ${pkgs.mullvad}/bin/mullvad connect
      '';
    };
  };
}
