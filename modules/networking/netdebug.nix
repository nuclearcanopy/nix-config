{
  # Snapshot tool for diagnosing networking crashes (see docs/networking.md).
  # Captures NM/Proton VPN/kernel state to a
  # timestamped file so the evidence survives a reconnect or reboot.
  nixos.modules.network-debug = { pkgs, ... }: {
    environment.systemPackages = [
      (pkgs.writeShellApplication {
        name = "netdebug";
        runtimeInputs = with pkgs; [
          networkmanager
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
          run "Proton WireGuard interface" wg show proton0
          run "wg show all"               wg show all
          run "Proton VPN GUI service"    systemctl --user status --no-pager -l protonvpn-gui

          run "systemctl status NetworkManager" systemctl status --no-pager -l NetworkManager

          run "journal: NetworkManager (last 15min)" \
            journalctl --no-pager --since "-15 min" \
              -u NetworkManager

          run "journal: kernel wifi/firmware (this boot)" \
            bash -c "journalctl -k --no-pager -b | grep -iE 'iwlwifi|ax210|firmware|ucode|microcode' | tail -n 200"

          echo "wrote $out"
        '';
      })
    ];
  };
}
