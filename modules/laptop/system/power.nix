{ pkgs, ... }:

{
  # TLP manages CPU frequency governors per AC/BAT state.
  # AC: let it rip. Battery: maximum power savings.
  # Conflicts with power-profiles-daemon — disable it.
  services.power-profiles-daemon.enable = false;

  # Powertop auto-tune catches anything TLP misses
  powerManagement.powertop.enable = true;

  # Thermald for thermal management
  services.thermald.enable = true;

  # Add powertop for manual inspection
  environment.systemPackages = [ pkgs.powertop ];

  services.tlp = {
    enable = true;
    settings = {
      # ═══════════════════════════════════════════════════════════════════
      # AC MODE: UNLEASHED — full performance, no limits
      # ═══════════════════════════════════════════════════════════════════
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_SCALING_MIN_FREQ_ON_AC = 400000;         # 400 MHz floor
      CPU_SCALING_MAX_FREQ_ON_AC = 4500000;        # 4.5 GHz ceiling
      CPU_BOOST_ON_AC = 1;                         # turbo ON
      PLATFORM_PROFILE_ON_AC = "performance";      # full send
      PCIE_ASPM_ON_AC = "default";                 # let hardware decide
      SATA_LINKPWR_ON_AC = "max_performance";
      AHCI_RUNTIME_PM_ON_AC = "on";                # no runtime PM on AC
      RUNTIME_PM_ON_AC = "on";                     # PCI devices stay awake
      WIFI_PWR_ON_AC = "off";                      # wifi full power
      SOUND_POWER_SAVE_ON_AC = 0;                  # no audio power save

      # ═══════════════════════════════════════════════════════════════════
      # BATTERY MODE: ULTRA AGGRESSIVE — squeeze every drop
      # ═══════════════════════════════════════════════════════════════════
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";     # most aggressive
      CPU_SCALING_MIN_FREQ_ON_BAT = 400000;        # 400 MHz floor
      CPU_SCALING_MAX_FREQ_ON_BAT = 1000000;       # 1.0 GHz cap (max battery)
      CPU_BOOST_ON_BAT = 0;                        # turbo OFF
      CPU_HWP_ON_BAT = "power";                    # Intel HWP energy bias
      CPU_HWP_DYN_BOOST_ON_BAT = 0;                # disable dynamic boost
      CPU_MIN_PERF_ON_BAT = 5;                     # Intel P-state min perf
      CPU_MAX_PERF_ON_BAT = 20;                    # Intel P-state max perf
      PLATFORM_PROFILE_ON_BAT = "low-power";
      SCHED_POWERSAVE_ON_BAT = 1;                  # scheduler powersave
      PCIE_ASPM_ON_BAT = "powersupersave";
      SATA_LINKPWR_ON_BAT = "min_power";
      AHCI_RUNTIME_PM_ON_BAT = "auto";
      RUNTIME_PM_ON_BAT = "auto";
      WIFI_PWR_ON_BAT = "on";                      # wifi power save
      SOUND_POWER_SAVE_ON_BAT = 60;                # 60s timeout before sleep
      SOUND_POWER_SAVE_CONTROLLER = "Y";

      # ═══════════════════════════════════════════════════════════════════
      # SHARED / BATTERY HEALTH
      # ═══════════════════════════════════════════════════════════════════
      # Battery charge thresholds — reduce wear
      START_CHARGE_THRESH_BAT0 = 20;
      STOP_CHARGE_THRESH_BAT0 = 80;

      # USB autosuspend
      USB_AUTOSUSPEND = 1;
      USB_AUTOSUSPEND_DISABLE_ON_SHUTDOWN = 1;     # prevent wake from USB
      USB_EXCLUDE_BTUSB = 1;                       # BT reconnect jank

      # Disable radios on battery when not in use (TLP Radio Device Wizard)
      DEVICES_TO_DISABLE_ON_BAT_NOT_IN_USE = "bluetooth wwan";

      # NVMe APST (Autonomous Power State Transitions)
      DISK_APM_LEVEL_ON_AC = "254";                # max performance
      DISK_APM_LEVEL_ON_BAT = "128";               # aggressive power save
      DISK_SPINDOWN_TIMEOUT_ON_BAT = "1";          # spin down fast
      DISK_IOSCHED = "mq-deadline";                # efficient I/O scheduler

      # Wake-on-LAN off (saves power)
      WOL_DISABLE = "Y";
    };
  };

  # Lid close: suspend on battery, keep awake option on AC
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "suspend";
    HandlePowerKey = "suspend";
    IdleAction = "suspend";
    IdleActionSec = "15min";
  };

  # Suspend-then-hibernate: if suspended for 30min, hibernate to save more power
  # (requires swap >= RAM size for hibernation)
  systemd.sleep.extraConfig = ''
    AllowSuspendThenHibernate=yes
    HibernateDelaySec=1800
  '';
}
