{ ... }:

{
  # TLP manages CPU frequency governors per AC/BAT state so laptop stays
  # cool on battery without sacrificing AC performance.
  # Conflicts with power-profiles-daemon — disable it.
  services.power-profiles-daemon.enable = false;

  services.tlp = {
    enable = true;
    settings = {
      # CPU governor: efficient always, powersave on battery
      CPU_SCALING_GOVERNOR_ON_AC = "powersave";    # schedutil burns more power
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

      # AMD P-State energy/performance hints — aggressive power saving
      CPU_ENERGY_PERF_POLICY_ON_AC = "balance_power";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

      # CPU frequency limits on battery (lower max = less heat + power)
      CPU_SCALING_MIN_FREQ_ON_AC = 400000;         # 400 MHz
      CPU_SCALING_MAX_FREQ_ON_AC = 4500000;        # 4.5 GHz
      CPU_SCALING_MIN_FREQ_ON_BAT = 400000;        # 400 MHz
      CPU_SCALING_MAX_FREQ_ON_BAT = 2000000;       # 2.0 GHz cap on battery

      # Disable turbo boost on battery (huge power saver)
      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 0;

      # Platform profile (modern AMD laptops support this)
      PLATFORM_PROFILE_ON_AC = "balanced";
      PLATFORM_PROFILE_ON_BAT = "low-power";

      # Battery charge thresholds — reduce wear
      START_CHARGE_THRESH_BAT0 = 20;
      STOP_CHARGE_THRESH_BAT0 = 80;   # lower threshold = longer battery lifespan

      # USB autosuspend — good for battery, exclude BT to avoid reconnect jank
      USB_AUTOSUSPEND = 1;
      USB_EXCLUDE_BTUSB = 1;

      # Wifi power saving on battery
      WIFI_PWR_ON_AC = "off";
      WIFI_PWR_ON_BAT = "on";

      # PCIe ASPM — force powersupersave always
      PCIE_ASPM_ON_AC = "powersupersave";
      PCIE_ASPM_ON_BAT = "powersupersave";

      # Runtime PM for all PCI devices
      RUNTIME_PM_ON_AC = "auto";
      RUNTIME_PM_ON_BAT = "auto";

      # SATA link power management
      SATA_LINKPWR_ON_AC = "med_power_with_dipm";
      SATA_LINKPWR_ON_BAT = "min_power";

      # Audio power saving
      SOUND_POWER_SAVE_ON_AC = 1;
      SOUND_POWER_SAVE_ON_BAT = 1;
      SOUND_POWER_SAVE_CONTROLLER = "Y";

      # NVMe power saving
      AHCI_RUNTIME_PM_ON_AC = "auto";
      AHCI_RUNTIME_PM_ON_BAT = "auto";
    };
  };

  # Lid close always suspends (on AC and battery)
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "suspend";
  };
}
