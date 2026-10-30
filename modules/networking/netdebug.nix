{
  # Snapshot tool for diagnosing networking crashes (Mullvad lockdown mode
  # means a broken tunnel can look like "no internet at all" with little
  # clue why; see docs/networking.md). Captures NM/mullvad/kernel state to a
  # timestamped file so the evidence survives a reconnect or reboot.
  nixos.modules.network-debug = { pkgs, ... }: {
    environment.systemPackages = [
      (pkgs.writeShellApplication {
        name = "netdebug";
        runtimeInputs = with pkgs; [
          networkmanager
          mullvad
          iproute2
          util-linux # rfkill
          systemd # journalctl, resolvectl, systemctl
          wireguard-tools
          # writeShellApplication prepends to PATH rather than replacing it,
          # so these were inherited from the interactive session and the
          # script only worked when run by hand. mkdir/date/tail from
          # coreutils, grep, and the bash the script re-invokes itself with.
          coreutils
          gnugrep
          bash
        ];
        text = ''
          outdir="''${1:-$HOME/network-debug}"
          mkdir -p "$outdir"
          out="$outdir/netdebug-$(date +%Y%m%d-%H%M%S).log"

          section() { printf '\n===== %s =====\n' "$1" >>"$out"; }
          run() { section "$1"; shift; "$@" >>"$out" 2>&1 || echo "(failed: $*)" >>"$out"; }

          : >"$out"
          run "date / uname"              date -u
          run "uname -a"                  uname -a
          run "nmcli general status"      nmcli general status
          run "nmcli device status"       nmcli device status
          run "nmcli active connections"  nmcli connection show --active
          run "ip addr"                   ip -br addr
          run "ip link"                   ip -br link
          run "ip route"                  ip route
          run "ip -6 route"               ip -6 route
          run "rfkill"                    rfkill list
          run "resolvectl status"         resolvectl status
          run "mullvad status"            mullvad status -v
          run "mullvad lockdown-mode"     mullvad lockdown-mode get
          run "mullvad version"           mullvad version
          run "wg show"                   wg show all

          for svc in NetworkManager mullvad-daemon mullvad-lockdown mullvad-relink mullvad-autoconnect; do
            run "systemctl status $svc" systemctl status --no-pager -l "$svc"
          done

          run "journal: NM + mullvad units (last 15min)" \
            journalctl --no-pager --since "-15 min" \
              -u NetworkManager -u mullvad-daemon -u mullvad-lockdown \
              -u mullvad-relink -u mullvad-autoconnect

          run "journal: kernel wifi/firmware (this boot)" \
            bash -c "journalctl -k --no-pager -b | grep -iE 'iwlwifi|ax210|firmware|ucode|microcode' | tail -n 200"

          echo "wrote $out"
        '';
      })
    ];
  };
}
