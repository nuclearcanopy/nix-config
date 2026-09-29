{
  # Adaptive battery runtime estimator.
  #
  # The waybar battery readout used to divide remaining charge by
  # current_now * voltage_now. That is an instantaneous number, so the ETA
  # swung between ~2h and ~11h depending on what happened in the last five
  # seconds, and it was systematically wrong in both directions: a blanked
  # screen extrapolated to 20+ hours, a compile burst to under two.
  #
  # This service samples the machine's power-relevant state every 5s, keeps a
  # long history of it, and learns the distribution of *mean power over the
  # next N minutes* conditioned on that state. The ETA then solves
  # integral(P_forecast) = usable energy instead of assuming constant power.
  # See the module docstring in scripts/battery_model.py for the model itself.
  #
  # It runs as root for two reasons: intel-rapl `energy_uj` is 0400 root (a
  # 2020 side-channel fix, and the psys domain is the closest thing the T480
  # has to a whole-package power meter), and the history lives under
  # /var/lib. Cost is ~13ms of CPU per 5s tick, i.e. 0.26% of one core.
  nixos.modules.battery-model = { pkgs, ... }:
    let
      stateDir = "/var/lib/battery-model";

      # writePython3Bin flake8-checks the script at build time, so a typo or an
      # unused name fails the rebuild rather than the service. W503/W504 are
      # the mutually exclusive line-break-around-operator pair (flake8 enables
      # one by default, so ignoring both is the only consistent choice) and
      # E265 fires on the shebang the writer itself prepends.
      batteryModel = pkgs.writers.writePython3Bin "battery-model"
        {
          libraries = [ ];
          flakeIgnore = [ "E501" "W503" "W504" "E265" "E226" ];
        }
        (builtins.readFile ./scripts/battery_model.py);
    in
    {
      environment.systemPackages = [ batteryModel ];

      systemd.services.battery-model = {
        description = "Adaptive battery runtime estimator";
        wantedBy = [ "multi-user.target" ];
        after = [ "local-fs.target" ];

        # The estimator's whole job is to observe suspend/resume (it measures
        # S3 drain from the energy delta across the sleep), so it must not be
        # stopped for one. It detects the sleep itself by diffing CLOCK_BOOTTIME
        # against CLOCK_MONOTONIC.
        serviceConfig = {
          Type = "simple";
          ExecStart = "${batteryModel}/bin/battery-model daemon";
          Restart = "always";
          RestartSec = "10s";
          Nice = 10;
          IOSchedulingClass = "idle";

          StateDirectory = "battery-model";
          StateDirectoryMode = "0755";

          # Read-only everywhere except its own state directory. It needs
          # /sys and /proc readable, so ProtectKernelTunables (which only makes
          # them read-only) is fine; ProtectProc is not, because the workload
          # classifier reads every process's comm out of /proc/<pid>/stat.
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          PrivateDevices = true;
          NoNewPrivileges = true;
          RestrictSUIDSGID = true;
          RestrictRealtime = true;
          RestrictNamespaces = true;
          LockPersonality = true;
          MemoryDenyWriteExecute = false; # python jit-less, but cpython mmaps
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
          ProtectHostname = true;
          ProtectClock = true;
          SystemCallFilter = [ "@system-service" ];
          SystemCallArchitectures = "native";
          CapabilityBoundingSet = [ "" ];
          AmbientCapabilities = [ "" ];
          RestrictAddressFamilies = [ "AF_UNIX" ];

          MemoryMax = "256M";
        };
      };

      # `battery-model status` prints the current estimate and `battery-model
      # report` prints what the model has learned: per-horizon accuracy against
      # the naive estimator it replaced, draw by regime, the charge curve, and
      # measured S3 drain. The waybar module reads ${stateDir}/waybar.json,
      # which the daemon writes world-readable.
    };
}
