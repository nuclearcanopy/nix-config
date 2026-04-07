{ config, pkgs, lib, unstable, ... }:

{
  # Boot configuration
  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
  };

  # Console configuration
  console = {
    enable = true;
    colors = [
      "000000" "a04a4a" "758d5a" "a89971"
      "6c99ba" "9e4e85" "c0dfdd" "f0f0f0"
      "000000" "a04a4a" "758d5a" "a89971"
      "6c99ba" "9e4e85" "c0dfdd" "f0f0f0"
    ];
  };

  # TLP power management
  services.tlp = {
    enable = true;
    settings = {
      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 1;
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "performance";
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "performance";
    };
  };

  # Disable sleep/suspend/hibernate
  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };

  # Ignore lid switch
  services.logind.settings = {
    Login = {
      HandleLidSwitch = "ignore";
      HandleLidSwitchExternalPower = "ignore";
      HandleLidSwitchDocked = "ignore";
    };
  };

  # Localization
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

  # Keyboard layout
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # NAS mount
  fileSystems."/mnt/nas" = {
    device = "//192.168.0.123/nuclearcanopy";
    fsType = "cifs";
    options =
      let
        automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
      in
        # TODO: Move credentials to agenix
        ["${automount_opts},username=nuclearcanopy,password=REDACTED,uid=1000,gid=100"];
  };

  # System packages
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

  # Sudo without password for wheel group
  security.sudo.wheelNeedsPassword = false;
}
