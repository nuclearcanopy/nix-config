{
  # SUPER HEAVY logging + disk health. Everything cranked to debug/trace and
  # persisted to a 20G/30d journal, kernel printk maxed, NetworkManager +
  # mullvad-daemon + docker daemon + navidrome + cloudflared all instrumented,
  # smartd polls the SSD and snapshots health hourly. Companion to
  # [[server-watchdog]] which handles recovery — this module only observes.
  nixos.modules.server-observability = { config, pkgs, lib, ... }: {

    # ---- Journal: persistent, 20G ceiling, 30d retention, debug-level ----
    # RateLimit disabled so a chatty service can't silently drop lines.
    services.journald.extraConfig = ''
      Storage=persistent
      SystemMaxUse=20G
      SystemMaxFileSize=200M
      MaxRetentionSec=30day
      MaxLevelStore=debug
      MaxLevelSyslog=debug
      MaxLevelKMsg=debug
      MaxLevelConsole=info
      MaxLevelWall=emerg
      Audit=yes
      ForwardToSyslog=no
      RateLimitBurst=0
      RateLimitIntervalSec=0
    '';

    # Kernel printk = "current default minimum default_console".
    # 7 = KERN_DEBUG. Runtime only; keep boot-time verbosity sane to avoid
    # slowing early boot on this old laptop.
    boot.kernel.sysctl."kernel.printk" = "7 4 1 7";
    boot.consoleLogLevel = 7;

    # Kernel audit framework: config writes + navidrome data only.
    # Two firehose rules were removed (2026-08-23): they generated ~91% of the
    # entire journal for near-zero forensic value on this box.
    #   - `-S execve` logged every process exec (x4 companion records each); the
    #     watchdogs alone spawn dozens of procs/min.
    #   - `-w /var/lib/docker` logged every create/delete in docker's overlay2
    #     storage -- constant container churn, thousands of records/min.
    # Keep only the low-volume, high-signal watches on config + navidrome data.
    security.auditd.enable = true;
    security.audit = {
      enable = true;
      rules = [
        "-w /etc/nixos -p wa -k config-change"
        "-w /var/lib/navidrome -p wa -k navidrome-data"
      ];
    };

    # ---- NetworkManager: DEBUG on every domain, wpa events + dhcp + wg ----
    networking.networkmanager.settings.logging = {
      level = "DEBUG";
      domains = "ALL";
      audit = "true";
    };

    # ---- Mullvad daemon: trace-level rust logs + full backtraces ----
    systemd.services.mullvad-daemon.environment = {
      MULLVAD_LOG = "trace";
      RUST_LOG = "trace";
      RUST_BACKTRACE = "full";
    };

    # ---- Docker daemon: debug + prometheus metrics on loopback ----
    # metrics-addr lets promtool / curl scrape container/daemon internals.
    virtualisation.docker.daemon.settings = {
      debug = true;
      log-level = "debug";
      metrics-addr = "127.0.0.1:9323";
      experimental = true;
    };

    # ---- SMART: smartd runs continuously + hourly snapshot to a file ----
    # daily short self-test at 02:00, weekly long self-test Sat 03:00.
    services.smartd = {
      enable = true;
      autodetect = true;
      defaults.autodetected = "-a -o on -S on -s (S/../.././02|L/../../6/03)";
      notifications.wall.enable = true;
    };

    systemd.services.smart-log = {
      description = "Snapshot SMART health hourly to /var/log/smart-health.log";
      startAt = "hourly";
      path = [ pkgs.smartmontools pkgs.coreutils ];
      script = ''
        {
          echo "=== $(date -Is) ==="
          smartctl -H /dev/sda 2>&1 | grep -iE "result|passed|failed"
          smartctl -A /dev/sda 2>&1 | grep -iE "reallocated|pending|uncorrect|wear|percent|udma_crc|power_on_hours|temperature|program_fail|erase_fail"
          df -h / /boot | grep -v Filesystem
          echo
        } >> /var/log/smart-health.log
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
    };

    systemd.tmpfiles.rules = [
      "d /var/log/journal 0755 root systemd-journal -"
      "f /var/log/smart-health.log 0644 root root -"
    ];

    environment.systemPackages = with pkgs; [ smartmontools lm_sensors ];
  };
}
