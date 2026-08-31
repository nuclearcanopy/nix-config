{
  # Laptop networking on top of networking-base: MAC randomization (wifi +
  # ethernet), wifi power-save, NetworkManager-wait-online disabled for
  # faster boot.
  nixos.modules.network-laptop = { pkgs, ... }: {
    # saves ~5.5s on boot; mullvad-autoconnect handles its own nm readiness check
    systemd.services.NetworkManager-wait-online.enable = false;

    systemd.services.mullvad-daemon.serviceConfig.TimeoutStopSec = "5";

    # Lockdown mode: the daemon holds a blocking firewall policy whenever the
    # tunnel is not up, including before it has ever connected and while the
    # daemon is stopped. There is no traffic off this box except through
    # Mullvad (LAN excepted). Set on every boot so the state is declarative
    # rather than whatever is left in /etc/mullvad-vpn/settings.json.
    #
    # Consequence, deliberate: captive portals are unreachable. To use one,
    # `mullvad lockdown-mode set off`, log in, then `systemctl restart
    # mullvad-lockdown`. Nothing does that automatically any more.
    systemd.services.mullvad-lockdown = {
      description = "Enforce Mullvad lockdown mode";
      after = [ "mullvad-daemon.service" ];
      wants = [ "mullvad-daemon.service" ];
      wantedBy = [ "mullvad-daemon.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        TimeoutStartSec = 90;
      };
      script = ''
        set -uo pipefail
        i=0
        until timeout 10 ${pkgs.mullvad}/bin/mullvad status >/dev/null 2>&1; do
          i=$((i + 1))
          [ "$i" -ge 60 ] && { echo "mullvad daemon not ready after 60s" >&2; exit 1; }
          sleep 1
        done
        ${pkgs.mullvad}/bin/mullvad lockdown-mode set on
        # Daemon-level autoconnect: the daemon re-secures itself as soon as it
        # starts, without waiting for graphical.target or an NM event.
        ${pkgs.mullvad}/bin/mullvad auto-connect set on
      '';
    };

    # Safety net for the one case lockdown mode does not cover: the target
    # state being left at "disconnected" (manual `mullvad disconnect`, a GUI
    # click). Lockdown keeps traffic blocked there, so this restores
    # connectivity rather than protecting it. The dispatcher delegates here
    # instead of acting inline because nm-dispatcher kills scripts past ~20s.
    #
    # Also runs at login behind mullvad-autoconnect: that shared script gates
    # `connect` on NM reporting connectivity "full", which with the check
    # disabled reads "unknown" forever, so it burns its 20s loop before
    # falling through. This connects without asking anyone's permission.
    systemd.services.mullvad-relink = {
      description = "Re-establish Mullvad after a network change";
      after = [ "mullvad-daemon.service" "mullvad-autoconnect.service" ];
      wants = [ "mullvad-daemon.service" ];
      wantedBy = [ "graphical.target" ];
      serviceConfig = {
        Type = "oneshot";
        TimeoutStartSec = 120;
      };
      script = ''
        set -uo pipefail

        log() { ${pkgs.util-linux}/bin/logger -t mullvad-relink -- "$*"; }

        # No pipe into `head` here. `mullvad status` prints four lines (state,
        # relay, features, location); `head -n1` exits after the first and the
        # daemon takes SIGPIPE writing the rest, which `pipefail` turns into
        # 141 and the wrapper's `set -e` turns into a dead unit on the first
        # iteration. It only loses the race while the daemon is mid-reconnect,
        # i.e. exactly when this service matters. Capture, then cut in-shell.
        state() {
          local out=""
          out="$(timeout 10 ${pkgs.mullvad}/bin/mullvad status 2>/dev/null)" || true
          printf '%s' "''${out%%$'\n'*}"
        }

        # No connectivity gating on purpose. The check is disabled, and even
        # enabled it would deadlock: under lockdown the probe cannot reach
        # anything until the tunnel is up. `connect` is idempotent, so
        # re-issuing it while the daemon retries is harmless.
        i=0
        while [ "$i" -lt 12 ]; do
          s="$(state)"
          case "$s" in
            Connected*)  log "tunnel up ($s)"; exit 0 ;;
            Connecting*) ;;
            *)
              log "tunnel down ($s); connecting"
              timeout 30 ${pkgs.mullvad}/bin/mullvad connect || true
              ;;
          esac
          i=$((i + 1))
          sleep 5
        done

        log "still not up after 60s; last state '$(state)'"
      '';
    };

    networking.networkmanager = {
      wifi.powersave = true;
      wifi.scanRandMacAddress = true;
      wifi.macAddress = "random";
      ethernet.macAddress = "random";

      # No connectivity-check override here: the privacy module's blanket
      # disable stands. It existed only to feed captive-portal detection, and
      # under lockdown mode the probe is blocked until the tunnel is up, so a
      # "limited"/"portal" verdict says nothing about the link. Reading that
      # state and disconnecting on it is exactly what used to drop the tunnel
      # (and the killswitch) mid-recovery.

      # Nudge Mullvad back up after a link change. Classify and hand off only;
      # mullvad-relink.service does the work. This never disconnects.
      dispatcherScripts = [{
        type = "basic";
        source = pkgs.writeShellScript "mullvad-relink-dispatcher" ''
          IFACE="$1"
          ACTION="$2"

          case "$ACTION" in
            connectivity-change|up|dhcp4-change|dhcp6-change) ;;
            *) exit 0 ;;
          esac

          # Never react to the tunnel's own interface. Bringing wg0-mullvad up
          # emits `up`, and NM's connectivity state is still pre-tunnel at that
          # instant, so the old script read "limited" and disconnected the very
          # tunnel it had just established.
          case "$IFACE" in
            lo|wg0-mullvad|wg*|tun*) exit 0 ;;
          esac

          ${pkgs.systemd}/bin/systemctl start --no-block mullvad-relink.service
        '';
      }];
    };

    # iPhone USB tethering: usbmuxd negotiates pairing and brings up the
    # ethernet-over-USB interface that NetworkManager then picks up.
    services.usbmuxd.enable = true;

    # No captive-portal handling at all, by choice. captive-browser never
    # actually worked here (its SOCKS5 proxy is blocked by Mullvad's firewall
    # like everything else) and it dragged chromium into the closure. Portals
    # are now a manual, deliberate act: `mullvad lockdown-mode set off`, log
    # in, then `systemctl restart mullvad-lockdown` to re-arm.

    # VLC uses libmicrodns for Chromecast discovery; replies arrive as
    # multicast on 5353 which the stateful firewall won't associate with
    # the outbound query.
    networking.firewall.allowedUDPPorts = [ 5353 ];
  };
}
