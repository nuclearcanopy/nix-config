{ pkgs, ... }:

{
  # TLP manages CPU frequency governors per AC/BAT state.
  # AC: full performance. Battery: maximum power savings.
  services.power-profiles-daemon.enable = false;

  # Profile Sync Daemon: keeps browser profiles in RAM (tmpfs),
  # reducing SSD writes and improving responsiveness
  services.psd = {
    enable = true;
    resyncTimer = "30min";
  };

  environment.systemPackages = [ pkgs.powertop ];

  services.tlp = {
    enable = true;
    settings = {
      # ═══════════════════════════════════════════════════════════════════
      # AC MODE — full performance, no limits
      # ═══════════════════════════════════════════════════════════════════
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_DRIVER_OPMODE_ON_AC = "active";
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_SCALING_MIN_FREQ_ON_AC = 400000;
      CPU_SCALING_MAX_FREQ_ON_AC = 4500000;
      CPU_BOOST_ON_AC = 1;
      PLATFORM_PROFILE_ON_AC = "performance";
      AMDGPU_ABM_LEVEL_ON_AC = 0;
      PCIE_ASPM_ON_AC = "performance";
      SATA_LINKPWR_ON_AC = "max_performance";
      AHCI_RUNTIME_PM_ON_AC = "on";
      RUNTIME_PM_ON_AC = "on";
      WIFI_PWR_ON_AC = "off";
      SOUND_POWER_SAVE_ON_AC = 0;

      # ═══════════════════════════════════════════════════════════════════
      # BATTERY MODE — aggressive power savings
      # ═══════════════════════════════════════════════════════════════════
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_DRIVER_OPMODE_ON_BAT = "active";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      CPU_SCALING_MIN_FREQ_ON_BAT = 400000;
      CPU_SCALING_MAX_FREQ_ON_BAT = 2000000;        # 2 GHz cap
      CPU_BOOST_ON_BAT = 0;
      PLATFORM_PROFILE_ON_BAT = "low-power";
      SCHED_POWERSAVE_ON_BAT = 1;                    # scx_lavd handles responsiveness
      AMDGPU_ABM_LEVEL_ON_BAT = 4;                   # max adaptive backlight dimming
      PCIE_ASPM_ON_BAT = "powersupersave";
      SATA_LINKPWR_ON_BAT = "min_power";
      AHCI_RUNTIME_PM_ON_BAT = "auto";
      RUNTIME_PM_ON_BAT = "auto";
      WIFI_PWR_ON_BAT = "on";
      SOUND_POWER_SAVE_ON_BAT = 60;
      SOUND_POWER_SAVE_CONTROLLER = "Y";

      # ═══════════════════════════════════════════════════════════════════
      # SHARED / BATTERY HEALTH
      # ═══════════════════════════════════════════════════════════════════
      START_CHARGE_THRESH_BAT0 = 20;
      STOP_CHARGE_THRESH_BAT0 = 80;

      # USB autosuspend — enabled; internal keyboard is PS/2 (unaffected)
      USB_AUTOSUSPEND = 1;
      USB_AUTOSUSPEND_DISABLE_ON_SHUTDOWN = 1;
      USB_EXCLUDE_BTUSB = 1;
      USB_EXCLUDE_AUDIO = 1;
      USB_EXCLUDE_PHONE = 1;

      DEVICES_TO_DISABLE_ON_BAT_NOT_IN_USE = "bluetooth wwan";

      DISK_APM_LEVEL_ON_AC = "254";
      DISK_APM_LEVEL_ON_BAT = "128";
      DISK_SPINDOWN_TIMEOUT_ON_BAT = "1";
      DISK_IOSCHED = "mq-deadline";

      WOL_DISABLE = "Y";
    };
  };

  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "suspend";
    HandlePowerKey = "suspend";
    IdleAction = "suspend";
    IdleActionSec = "15min";
  };

  systemd.sleep.extraConfig = ''
    AllowSuspendThenHibernate=yes
    HibernateDelaySec=1800
  '';
}
