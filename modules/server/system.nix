{
  # Server baseline: nix settings tuned for 128GB SSD (daily GC, 7-day retention),
  # systemd-boot, MCE/panic kernel params, console palette, TLP powersave with
  # boost on, thermald + irqbalance, docker priority, network buffer tuning for
  # streaming, zramSwap, hardware watchdog, suspend/hibernate disabled, autologin,
  # lid switch ignored, Romanian locale, CIFS NAS mount, system packages, sudo
  # passwordless for wheel, polkit rule for user-triggered navidrome sync.
  nixos.modules.server-system = { config, pkgs, lib, unstable, username, allowedUnfree, ... }: {
    system.stateVersion = "25.11";

    nix = {
      settings = {
        experimental-features = [ "nix-command" "flakes" ];
        auto-optimise-store = true;
      };

      gc = {
        automatic = true;
        dates = "daily";
        options = "--delete-older-than 7d";
      };
    };

    boot = {
      loader.systemd-boot.enable = true;
      loader.efi.canTouchEfiVariables = true;
      loader.systemd-boot.configurationLimit = 5;
      loader.timeout = 3;

      # MCE: keep machine check exceptions enabled with recovery attempts.
      # panic_on_oops forces a clean reboot instead of limping along corrupted.
      kernelParams = [ "mce=1" "panic_on_oops=1" ];

      kernel.sysctl = {
        "vm.swappiness" = 10;
        "vm.dirty_ratio" = 10;
        "vm.dirty_background_ratio" = 5;
        "net.core.rmem_max" = 16777216;
        "net.core.wmem_max" = 16777216;
        "net.ipv4.tcp_rmem" = "4096 87380 16777216";
        "net.ipv4.tcp_wmem" = "4096 65536 16777216";
        "kernel.panic" = 30;
        "kernel.panic_on_oops" = 1;
      };
    };

    console = {
      enable = true;
      colors = [
        "000000" "a04a4a" "758d5a" "a89971"
        "6c99ba" "9e4e85" "c0dfdd" "f0f0f0"
        "000000" "a04a4a" "758d5a" "a89971"
        "6c99ba" "9e4e85" "c0dfdd" "f0f0f0"
      ];
    };

    services.tlp = {
      enable = true;
      settings = {
        CPU_SCALING_GOVERNOR_ON_AC = "powersave";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
        CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
        CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_performance";
        CPU_BOOST_ON_AC = 1;
        CPU_BOOST_ON_BAT = 1;
        CPU_HWP_DYN_BOOST_ON_AC = 1;
        CPU_HWP_DYN_BOOST_ON_BAT = 1;
        CPU_SCALING_MIN_FREQ_ON_AC = 0;
        CPU_SCALING_MAX_FREQ_ON_AC = 0;
        CPU_SCALING_MIN_FREQ_ON_BAT = 0;
        CPU_SCALING_MAX_FREQ_ON_BAT = 0;
        PLATFORM_PROFILE_ON_AC = "balanced";
        PLATFORM_PROFILE_ON_BAT = "balanced";
      };
    };

    services.thermald.enable = true;
    services.irqbalance.enable = true;

    # Higher scheduling priority for docker containers.
    systemd.services.docker = {
      serviceConfig = {
        Nice = -5;
        IOSchedulingClass = "realtime";
        IOSchedulingPriority = 2;
      };
    };

    # Log Machine Check Exceptions to a queryable DB. After boot:
    # rasdaemon -q (or journalctl -u rasdaemon) for error history.
    hardware.rasdaemon.enable = true;

    zramSwap = {
      enable = true;
      algorithm = "zstd";
      memoryPercent = 50;
    };

    # Hardware watchdog: forces a hardware reset if the kernel hard-locks.
    systemd.settings.Manager = {
      RuntimeWatchdogSec = "60s";
      RebootWatchdogSec = "10m";
    };

    systemd.targets = {
      sleep.enable = false;
      suspend.enable = false;
      hibernate.enable = false;
      hybrid-sleep.enable = false;
    };

    services.getty.autologinUser = username;

    services.logind.settings = {
      Login = {
        HandleLidSwitch = "ignore";
        HandleLidSwitchExternalPower = "ignore";
        HandleLidSwitchDocked = "ignore";
      };
    };

    time.timeZone = "Europe/Bucharest";

    i18n.defaultLocale = "en_US.UTF-8";
    i18n.extraLocaleSettings = {
      LC_ADDRESS = "ro_RO.UTF-8";
      LC_IDENTIFICATION = "ro_RO.UTF-8";
      LC_MEASUREMENT = "ro_RO.UTF-8";
      LC_MONETARY = "ro_RO.UTF-8";
      LC_NAME = "ro_RO.UTF-8";
      LC_NUMERIC = "ro_RO.UTF-8";
      LC_PAPER = "ro_RO.UTF-8";
      LC_TELEPHONE = "ro_RO.UTF-8";
      LC_TIME = "ro_RO.UTF-8";
    };

    fileSystems."/mnt/nas" = {
      device = "//192.168.0.123/${username}";
      fsType = "cifs";
      options =
        let
          automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
        in
          [
            "${automount_opts}"
            "credentials=${config.age.secrets.nas-credentials.path}"
            "uid=${toString config.users.users.${username}.uid}"
            "gid=100"
          ];
    };

    nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) allowedUnfree;

    environment.systemPackages = with pkgs; [
      zsh
      neovim
      curl
      cifs-utils
      btop
      wget
      git
      gh
      mullvad
      deno
      nodejs
      (python3.withPackages (ps: [ ps.mutagen ps.flask ]))
      unstable.yt-dlp
      ffmpeg
      claude-code
      rsync
    ];

    users.users.${username}.uid = 1000;

    security.sudo.wheelNeedsPassword = false;

    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (
          action.id === "org.freedesktop.systemd1.manage-units" &&
          action.lookup("unit") === "navidrome-sync-from-nas.service" &&
          action.lookup("verb") === "start" &&
          subject.user === "${username}"
        ) {
          return polkit.Result.YES;
        }
      });
    '';
  };
}
