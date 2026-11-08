{
  # Failsafe layer for the homeserver, which runs on aging laptop hardware and
  # cuts out often. Complements the hardware watchdog + panic_on_oops already in
  # server-system with:
  #   - Restart=always (no start-limit ceiling) on every docker container unit
  #   - a 2-min health-check loop that curls each service and escalates
  #     container-restart -> docker-stack bounce -> reboot, with an egress
  #     precheck so a Mullvad/WiFi flap doesn't trigger useless restarts; for
  #     the tunnel (cloudflared), when egress is alive but the tunnel is down
  #     -- a flapping Mullvad relay -- it cycles the VPN (`mullvad reconnect`)
  #     for a fresh relay before ever rebooting, since a reboot only re-dials
  #     the same bad relay and loops
  #   - a 1-min network watchdog that pings out through the tunnel and cycles
  #     mullvad-daemon -> NetworkManager -> reboot when egress stays dead
  #   - Restart=always on the docker daemon itself
  #   - earlyoom to kill a runaway process before the box OOM-hangs
  #   - reboot-log: on every boot, appends the previous session's shutdown
  #     reason + last dmesg errors + watchdog state to /var/log/reboot-history.log
  # See also: [[server-observability]] for the SUPER HEAVY logging layer.
  nixos.modules.server-watchdog = { config, pkgs, lib, ... }:

    let
      healthcheck = pkgs.writeShellScript "server-watchdog"
        (builtins.readFile ./scripts/healthcheck.sh);
      netWatchdog = pkgs.writeShellScript "net-watchdog"
        (builtins.readFile ./scripts/net-watchdog.sh);
      rebootLog = pkgs.writeShellScript "reboot-log"
        (builtins.readFile ./scripts/reboot-log.sh);

      # container units that should come straight back after any exit/crash,
      # with the systemd start-limit disabled: a container flapping fast enough
      # to hit the default 5-in-10s ceiling gets marked failed and stays down
      # until a reboot, which defeats the whole point of Restart=always.
      restartAlways = restartSec: names:
        lib.genAttrs (map (n: "docker-${n}") names) (_: {
          serviceConfig = {
            Restart = lib.mkForce "always";
            RestartSec = restartSec;
          };
          startLimitIntervalSec = 0;
          startLimitBurst = 0;
        });
    in
    {
      systemd.services =
        # most containers bounce back fast (5s).
        restartAlways "5s" [ "navidrome" "portainer" "cloudflared" ]
        # filebrowser bind-mounts /mnt/nas; when the NAS is down it exits 125 on
        # every start. retry gently every 30s (re-triggering the autofs mount
        # each attempt) instead of hammering every 5s -- the healthcheck's NAS
        # precheck already keeps it from ever escalating to a box reboot.
        // restartAlways "30s" [ "filebrowser" ]
        // {
        # Keep the docker daemon itself alive; without this a daemon crash
        # strands every container until the daily reboot.
        docker = {
          serviceConfig = {
            Restart = lib.mkForce "always";
            RestartSec = "5s";
          };
          startLimitIntervalSec = 0;
          startLimitBurst = 0;
        };

        server-watchdog = {
          description = "Health-check core services and escalate recovery";
          after = [ "docker.service" ];
          # mullvad: the cloudflared/egress rung cycles the VPN transport
          # (`mullvad reconnect`) when the tunnel is down but egress is alive.
          path = [ pkgs.curl pkgs.docker pkgs.systemd pkgs.coreutils pkgs.mullvad ];
          serviceConfig = {
            Type = "oneshot";
            User = "root";
            ExecStart = "${healthcheck}";
          };
        };

        net-watchdog = {
          description = "Ping-based network watchdog: cycle mullvad -> NM -> reboot";
          after = [ "network-online.target" "mullvad-daemon.service" ];
          wants = [ "network-online.target" ];
          path = [ pkgs.iputils pkgs.curl pkgs.systemd pkgs.coreutils ];
          serviceConfig = {
            Type = "oneshot";
            User = "root";
            ExecStart = "${netWatchdog}";
          };
        };

        reboot-log = {
          description = "Log the previous session's reboot cause to /var/log/reboot-history.log";
          wantedBy = [ "multi-user.target" ];
          after = [ "systemd-journald.service" ];
          path = [ pkgs.systemd pkgs.coreutils pkgs.gnugrep pkgs.gawk ];
          serviceConfig = {
            Type = "oneshot";
            User = "root";
            ExecStart = "${rebootLog}";
            RemainAfterExit = true;
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

      systemd.timers.net-watchdog = {
        description = "Run the network watchdog every minute";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "2min";
          OnUnitActiveSec = "1min";
        };
      };

      systemd.tmpfiles.rules = [
        "f /var/log/reboot-history.log 0644 root root -"
      ];

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
