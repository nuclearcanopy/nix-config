{
  # Uptime accounting, in two halves.
  #
  # `uptimed` keeps the classic highest-uptime leaderboard (`uprecords`), and
  # that is all it is used for here. It cannot double as a lifetime "playtime"
  # total: its clock is CLOCK_BOOTTIME, which keeps running across S3 (on this
  # laptop ~62% of boot-to-shutdown wall time is suspend, measured over the
  # month of journal retention on 2026-10-28), and its defaults prune the log
  # to 50 entries and drop any session under 1h. Its config lives inside the
  # store path (`-DFILE_CONFIG=$out/etc/uptimed.conf`), so changing either
  # default would mean overriding the package.
  #
  # `playtime` is the cumulative counter: a 2-minute tick folding elapsed
  # CLOCK_MONOTONIC into /var/lib/playtime/state.json, so suspend is excluded
  # and a crash loses at most one tick. The pre-existing total is a Nix
  # constant below rather than a pre-baked state file, so it can be corrected
  # by editing this module.
  nixos.modules.uptimed = { pkgs, ... }:
    let
      # Hours the machine had already run before this counter existed. Taken
      # from the NVMe's SMART "Power On Hours" on 2026-10-28 (WDC PC SN720,
      # 4383h / 6178 power cycles), which is drive lifetime: it predates this
      # NixOS install (2026-05-18, itself only ~2555h of session time) and
      # predates buying the laptop, which is the intent. The drive is powered
      # down in S3, so this counts awake hours, same as the tick below.
      #
      # nidhoggr-specific. If another host ever imports this bucket, promote
      # the constant to an option first.
      seedHours = 4383;

      playtime = pkgs.writers.writePython3Bin "playtime"
        {
          libraries = [ ];
          flakeIgnore = [ "E501" "W503" "W504" "E265" "E226" ];
        }
        (builtins.readFile ./scripts/playtime.py);
    in
    {
      services.uptimed.enable = true;

      environment.systemPackages = [ playtime ];
      environment.etc."playtime-seed".text = toString (seedHours * 3600);

      systemd.services.playtime-tick = {
        description = "Fold elapsed awake time into the playtime total";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${playtime}/bin/playtime tick";

          StateDirectory = "playtime";
          StateDirectoryMode = "0755";

          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          PrivateDevices = true;
          PrivateNetwork = true;
          NoNewPrivileges = true;
          RestrictNamespaces = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          LockPersonality = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
          ProtectClock = true;
          SystemCallFilter = [ "@system-service" ];
          SystemCallArchitectures = "native";
          CapabilityBoundingSet = [ "" ];
        };
      };

      systemd.timers.playtime-tick = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "1min";
          OnUnitActiveSec = "2min";
          # Let systemd coalesce this with other wakeups; a minute of slack
          # costs nothing against a four-digit hour count.
          AccuracySec = "1min";
        };
      };
    };
}
