{
  # `sil` CPU mode ("red LAP" in waybar): lap power limits plus the thinkpad
  # fan pinned to level 0, for sleeping next to the laptop while work runs.
  # thinkfan cannot be left running (it would re-raise the level every tick),
  # so fan-silence.service owns the fan while the mode is active and hands it
  # back on stop. Vents at 90C as a hardware backstop; see docs/power.md.
  #
  # The .path unit watching the CPU-mode state file is what keeps this
  # privilege-free: set-cpu-mode runs unprivileged from waybar and only writes
  # the state file, and this root-side reconciler moves fan ownership to match.
  nixos.modules.fan-silence = { pkgs, ... }:

    let
      stateFile = "/var/lib/cpu-mode/state";
      fanPath = "/proc/acpi/ibm/fan";

      # Emergency vent threshold, millidegrees. In `sil` the package is capped
      # at PL1=15W/2GHz and settles around 60C, so this should never fire; it
      # exists so a stuck workload or a blocked vent cannot cook the board.
      ventMilliC = 90000;

      # Re-pins every 2s rather than writing level 0 once: the EC takes the fan
      # back over on resume from S3, and thinkpad_acpi's fan watchdog expires.
      silenceLoop = pkgs.writeShellScript "fan-silence-loop" ''
        set -u
        while :; do
          t=0
          for f in /sys/devices/platform/coretemp.0/hwmon/hwmon*/temp*_input; do
            v=$(cat "$f" 2>/dev/null) || continue
            [ "$v" -gt "$t" ] && t="$v"
          done
          if [ "$t" -ge ${toString ventMilliC} ]; then
            printf 'level 7\n' > ${fanPath} || true
            sleep 15
          else
            printf 'level 0\n' > ${fanPath} || true
            sleep 2
          fi
        done
      '';

      # Hand the fan back to the EC before thinkfan restarts, so a thinkfan
      # start failure cannot leave the fan pinned off.
      releaseFan = pkgs.writeShellScript "fan-silence-release" ''
        printf 'level auto\n' > ${fanPath} 2>/dev/null || true
      '';

      reconcile = pkgs.writeShellScript "fan-silence-reconcile" ''
        set -u
        mode=$(cat ${stateFile} 2>/dev/null || true)
        if [ "$mode" = "sil" ]; then
          # Conflicts=thinkfan.service makes this start stop thinkfan.
          exec ${pkgs.systemd}/bin/systemctl start --no-block fan-silence.service
        fi
        ${pkgs.systemd}/bin/systemctl stop fan-silence.service || true
        exec ${pkgs.systemd}/bin/systemctl start --no-block thinkfan.service
      '';
    in
    {
      systemd.services.fan-silence = {
        description = "Pin the thinkpad fan to level 0 (sil CPU mode)";
        conflicts = [ "thinkfan.service" ];
        path = [ pkgs.coreutils ];
        serviceConfig = {
          Type = "simple";
          ExecStart = "${silenceLoop}";
          ExecStopPost = "${releaseFan}";
          Restart = "always";
          RestartSec = "2s";
          # waybar's thermal_mode.sh tests for this directory to colour LAP
          # red; systemd removes it when the unit stops, so it cannot go stale.
          RuntimeDirectory = "fan-silence";
        };
      };

      # Reacts to set-cpu-mode writing the state file. Also runs once at boot,
      # after cpu-mode-restore has re-applied the sticky mode, because
      # PathChanged does not fire for a file that already exists unchanged.
      systemd.services.fan-silence-reconcile = {
        description = "Match fan ownership to the current CPU mode";
        after = [ "cpu-mode-restore.service" "thinkfan.service" ];
        wantedBy = [ "graphical.target" ];
        path = [ pkgs.coreutils ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${reconcile}";
        };
      };

      systemd.paths.fan-silence-reconcile = {
        description = "Watch the CPU mode state file for sil transitions";
        wantedBy = [ "multi-user.target" ];
        pathConfig.PathChanged = stateFile;
      };
    };
}
