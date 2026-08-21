{
  # Failsafe layer for the homeserver, which runs on aging laptop hardware and
  # cuts out often. Complements the hardware watchdog + panic_on_oops already in
  # server-system with:
  #   - Restart=always on every docker container unit (not just navidrome)
  #   - a 2-min health-check loop that curls each service and escalates
  #     container-restart -> docker-stack bounce -> reboot
  #   - Restart=always on the docker daemon itself
  #   - earlyoom to kill a runaway process before the box OOM-hangs
  nixos.modules.server-watchdog = { config, pkgs, lib, ... }:

    let
      healthcheck = pkgs.writeShellScript "server-watchdog"
        (builtins.readFile ./scripts/healthcheck.sh);

      # container units that should come straight back after any exit/crash.
      # docker-navidrome already forces this in server-services; the rest were
      # relying on the oci-containers default (no restart), so a crash took them
      # down until the next boot.
      restartAlways = names:
        lib.genAttrs (map (n: "docker-${n}") names) (_: {
          serviceConfig = {
            Restart = lib.mkForce "always";
            RestartSec = "5s";
          };
        });
    in
    {
      systemd.services = restartAlways [ "filebrowser" "portainer" "cloudflared" ] // {
        # Keep the docker daemon itself alive; without this a daemon crash
        # strands every container until the daily reboot.
        docker.serviceConfig = {
          Restart = lib.mkForce "always";
          RestartSec = "5s";
        };

        server-watchdog = {
          description = "Health-check core services and escalate recovery";
          after = [ "docker.service" ];
          path = [ pkgs.curl pkgs.docker pkgs.systemd pkgs.coreutils ];
          serviceConfig = {
            Type = "oneshot";
            User = "root";
            ExecStart = "${healthcheck}";
          };
        };
      };

      systemd.timers.server-watchdog = {
        description = "Run the server watchdog every 2 minutes";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "3min";
          OnUnitActiveSec = "2min";
        };
      };

      # Kill the fattest process before the kernel OOM-killer hard-locks the box.
      # Notifications off: this host is headless.
      services.earlyoom = {
        enable = true;
        freeMemThreshold = 5;
        freeSwapThreshold = 10;
        enableNotifications = false;
      };
    };
}
