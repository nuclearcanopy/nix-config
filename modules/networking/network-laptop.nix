{
  # Laptop networking on top of networking-base: MAC randomization (wifi +
  # ethernet), wifi power-save, NetworkManager-wait-online disabled for
  # faster boot.
  nixos.modules.network-laptop = { pkgs, lib, ... }: {
    # saves ~5.5s on boot; mullvad-autoconnect handles its own nm readiness check
    systemd.services.NetworkManager-wait-online.enable = false;

    systemd.services.mullvad-daemon.serviceConfig.TimeoutStopSec = "5";

    networking.networkmanager = {
      wifi.powersave = true;
      wifi.scanRandMacAddress = true;
      wifi.macAddress = "random";
      ethernet.macAddress = "random";

      # Captive portal detection: NM sets state to "portal" when this HTTP GET
      # is intercepted, which the dispatcher below reads. Overrides the privacy
      # module's blanket disable because portals matter on a mobile device;
      # on nidhoggr the probe traverses Mullvad whenever the tunnel is up, so
      # nmcheck.gnome.org only sees the Mullvad exit IP.
      settings.connectivity = {
        enabled = lib.mkForce true;
        uri = lib.mkForce "http://nmcheck.gnome.org/check_network_status.txt";
        response = "NetworkManager is online";
        interval = 300;
      };

      # Roam between clean and captive networks without wedging Mullvad:
      # drop the tunnel when NM sees a portal/limited link, bring it back
      # when connectivity goes full. Runs on every NM state change.
      dispatcherScripts = [{
        type = "basic";
        source = pkgs.writeShellScript "mullvad-portal-dispatcher" ''
          IFACE="$1"
          ACTION="$2"

          case "$ACTION" in
            connectivity-change|up|dhcp4-change|dhcp6-change) ;;
            *) exit 0 ;;
          esac

          [ "$IFACE" = "lo" ] && exit 0

          CONN="$(${pkgs.networkmanager}/bin/nmcli -t networking connectivity 2>/dev/null || echo unknown)"

          case "$CONN" in
            full)
              ${pkgs.mullvad}/bin/mullvad status 2>/dev/null | grep -q "Disconnected" \
                && ${pkgs.mullvad}/bin/mullvad connect || true
              ;;
            portal|limited)
              ${pkgs.mullvad}/bin/mullvad disconnect || true
              ;;
          esac
        '';
      }];
    };

    # iPhone USB tethering: usbmuxd negotiates pairing and brings up the
    # ethernet-over-USB interface that NetworkManager then picks up.
    services.usbmuxd.enable = true;

    # captive-browser: a chromium-incognito wrapper that starts a local SOCKS5
    # proxy bound to wlp1s0 with DNS aimed at the DHCP-provided resolver, so
    # portal traffic sidesteps Mullvad, resolved, DoT, and Firefox DoH entirely.
    # Ships chromium in the closure (used only for portals; daily browser is
    # still Firefox). Run `captive-browser` on the portal wifi, log in, close.
    programs.captive-browser = {
      enable = true;
      interface = "wlp1s0";
      # NM knows the DHCP DNS for the active wifi; ask it directly.
      dhcp-dns = ''${pkgs.networkmanager}/bin/nmcli -g IP4.DNS dev show wlp1s0'';
    };

    # VLC uses libmicrodns for Chromecast discovery; replies arrive as
    # multicast on 5353 which the stateful firewall won't associate with
    # the outbound query.
    networking.firewall.allowedUDPPorts = [ 5353 ];
  };
}
