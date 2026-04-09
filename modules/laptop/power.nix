{ ... }:

{
  # TLP manages CPU frequency governors per AC/BAT state so laptop stays
  # cool on battery without sacrificing AC performance.
  # Conflicts with power-profiles-daemon — disable it.
  services.power-profiles-daemon.enable = false;

  services.tlp = {
    enable = true;
    settings = {
      # CPU governor: responsive on AC, efficient on battery
      CPU_SCALING_GOVERNOR_ON_AC = "schedutil";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

      # AMD P-State energy/performance hints
      CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

      # Platform profile (modern AMD laptops support this)
      PLATFORM_PROFILE_ON_AC = "balanced";
      PLATFORM_PROFILE_ON_BAT = "low-power";

      # Battery charge thresholds — slightly below 100% to reduce wear.
      # Charges to 95%, starts charging again at 20%.
      # Silently ignored if hardware doesn't support it.
      START_CHARGE_THRESH_BAT0 = 20;
      STOP_CHARGE_THRESH_BAT0 = 95;

      # USB autosuspend — good for battery, exclude BT to avoid reconnect jank
      USB_AUTOSUSPEND = 1;
      USB_EXCLUDE_BTUSB = 1;

      # Wifi power saving on battery
      WIFI_PWR_ON_AC = "off";
      WIFI_PWR_ON_BAT = "on";

      # PCIe ASPM
      PCIE_ASPM_ON_AC = "default";
      PCIE_ASPM_ON_BAT = "powersupersave";
    };
  };

  # Lid close always suspends (on AC and battery)
  services.logind.lidSwitch = "suspend";
  services.logind.lidSwitchExternalPower = "suspend";
}
