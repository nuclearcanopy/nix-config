{ config, pkgs, lib, unstable, ... }:

{
  system.stateVersion = "25.11";

  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
    };

    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 7d";  # More aggressive for 128GB SSD
    };
  };

  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
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
      # Use powersave governor (with intel_pstate, this still scales on demand)
      # This drops to low frequencies when idle, saving significant power
      CPU_SCALING_GOVERNOR_ON_AC = "powersave";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

      # Energy policy: balance_performance for fast streaming response
      # Options: performance > balance_performance > balance_power > power
      # balance_performance = quick ramp-up, still saves power at idle
      CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_performance";

      # Keep boost ENABLED - critical for fast single-thread when needed
      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 1;

      # Intel Hardware P-state dynamic boost - quick frequency ramp-up
      CPU_HWP_DYN_BOOST_ON_AC = 1;
      CPU_HWP_DYN_BOOST_ON_BAT = 1;

      # Don't limit min/max frequencies - let CPU use full range
      CPU_SCALING_MIN_FREQ_ON_AC = 0;
      CPU_SCALING_MAX_FREQ_ON_AC = 0;
      CPU_SCALING_MIN_FREQ_ON_BAT = 0;
      CPU_SCALING_MAX_FREQ_ON_BAT = 0;

      # Platform profile for balanced operation
      PLATFORM_PROFILE_ON_AC = "balanced";
      PLATFORM_PROFILE_ON_BAT = "balanced";
    };
  };

  # Enable thermald for Intel - helps with efficient thermal/power management
  services.thermald.enable = true;

  # IRQ balancing for better I/O responsiveness
  services.irqbalance.enable = true;

  # Give Docker containers higher scheduling priority for responsive streaming
  systemd.services.docker = {
    serviceConfig = {
      Nice = -5;           # Higher priority (-20 to 19, lower = higher priority)
      IOSchedulingClass = "realtime";
      IOSchedulingPriority = 2;  # 0-7, lower = higher priority
    };
  };

  # Kernel parameters for better responsiveness under load
  boot.kernel.sysctl = {
    # Reduce swappiness - prefer keeping things in RAM
    "vm.swappiness" = 10;
    # More aggressive dirty page writeback (better I/O responsiveness)
    "vm.dirty_ratio" = 10;
    "vm.dirty_background_ratio" = 5;
    # Increase network buffer sizes for streaming
    "net.core.rmem_max" = 16777216;
    "net.core.wmem_max" = 16777216;
    "net.ipv4.tcp_rmem" = "4096 87380 16777216";
    "net.ipv4.tcp_wmem" = "4096 65536 16777216";
  };

  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };

  services.getty.autologinUser = "homeserver";

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
    device = "//192.168.0.123/nuclearcanopy";
    fsType = "cifs";
    options =
      let
        automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
      in
        [
          "${automount_opts}"
          "credentials=${config.age.secrets.nas-credentials.path}"
          "uid=1000"
          "gid=100"
        ];
  };

  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "claude-code"
  ];

  environment.systemPackages = with pkgs; [
    zsh
    neovim
    curl
    cifs-utils
    btop
    wget
    git
    mullvad
    deno
    nodejs
    (python3.withPackages (ps: [ ps.mutagen ps.flask ]))
    unstable.yt-dlp  # Use unstable for latest yt-dlp
    ffmpeg
    claude-code
    rsync
  ];

  security.sudo.wheelNeedsPassword = false;

  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (
        action.id === "org.freedesktop.systemd1.manage-units" &&
        action.lookup("unit") === "navidrome-sync-from-nas.service" &&
        action.lookup("verb") === "start" &&
        subject.user === "homeserver"
      ) {
        return polkit.Result.YES;
      }
    });
  '';
}
