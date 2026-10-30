{
  # Safety net for caffeine mode left on with the lid closed (e.g. forgotten
  # before closing the lid to carry it in a bag). Caffeine's systemd-inhibit
  # blocks logind's lid-switch handling entirely (see caffeine.sh), so there
  # is no suspend and no event to hook; this polls instead. While caffeine is
  # on and the lid is closed it caps the CPU mode at `bal` (overriding
  # spd/god/auto), and powers off outright once the lid has stayed closed
  # for 30 minutes so a forgotten session can't run the battery to zero.
  nixos.modules.caffeine-watchdog = { pkgs, username, ... }:
    let
      stateDir = "/run/caffeine-watchdog";
      sinceFile = "${stateDir}/lid-closed-since";
      shutdownAfterSec = 30 * 60;

      check = pkgs.writeShellScript "caffeine-watchdog-check" ''
        set -eu
        mkdir -p ${stateDir}

        uid=$(${pkgs.coreutils}/bin/id -u ${username})
        pidfile="/run/user/$uid/waybar-caffeine.pid"

        caffeine_on=no
        if [ -f "$pidfile" ] && kill -0 "$(${pkgs.coreutils}/bin/cat "$pidfile")" 2>/dev/null; then
          caffeine_on=yes
        fi

        lid_closed=no
        if ${pkgs.gnugrep}/bin/grep -q closed /proc/acpi/button/lid/*/state 2>/dev/null; then
          lid_closed=yes
        fi

        if [ "$caffeine_on" = yes ] && [ "$lid_closed" = yes ]; then
          # Cap every tick, not just on the first transition, in case
          # something (e.g. an SSH session) bumps the mode back up while
          # cocooned.
          mode=$(${pkgs.coreutils}/bin/cat /var/lib/cpu-mode/state 2>/dev/null || true)
          case "$mode" in
            # `|| true` matters: this runs under `set -eu`, so a nonzero exit
            # here would abort the tick before the poweroff check below and
            # the 30-minute drain timer would never advance.
            spd|god|"") /run/current-system/sw/bin/set-cpu-mode bal || true ;;
          esac

          [ -f ${sinceFile} ] || ${pkgs.coreutils}/bin/date +%s > ${sinceFile}
          since=$(${pkgs.coreutils}/bin/cat ${sinceFile})
          now=$(${pkgs.coreutils}/bin/date +%s)
          if [ $(( now - since )) -ge ${toString shutdownAfterSec} ]; then
            ${pkgs.systemd}/bin/systemctl poweroff
          fi
        else
          rm -f ${sinceFile}
        fi
      '';
    in
    {
      systemd.services.caffeine-watchdog = {
        description = "Cap CPU mode / shut down if caffeine mode is on with the lid closed";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${check}";
        };
      };

      systemd.timers.caffeine-watchdog = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "30s";
          OnUnitActiveSec = "30s";
        };
      };
    };
}
