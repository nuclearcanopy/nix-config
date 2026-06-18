{
  # TLP: AC = adaptive turbo on demand; battery = aggressive power savings.
  # Battery health thresholds (20/80) work via the thinkpad plugin + natacpi
  # after SMBIOS product_name was fixed to "ThinkPad T480" in Libreboot config.
  nixos.modules.tlp = {
    # power-profiles-daemon would race with TLP for governor control.
    services.power-profiles-daemon.enable = false;

    services.tlp = {
      enable = true;
      settings = {
        # AC
        CPU_SCALING_GOVERNOR_ON_AC = "powersave";
        CPU_DRIVER_OPMODE_ON_AC = "active";
        CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
        CPU_SCALING_MIN_FREQ_ON_AC = 400000;
        CPU_SCALING_MAX_FREQ_ON_AC = 3600000;        # i5-8350U turbo max
        CPU_BOOST_ON_AC = 1;
        PLATFORM_PROFILE_ON_AC = "performance";
        PCIE_ASPM_ON_AC = "performance";
        SATA_LINKPWR_ON_AC = "max_performance";
        AHCI_RUNTIME_PM_ON_AC = "on";
        RUNTIME_PM_ON_AC = "on";
        WIFI_PWR_ON_AC = "off";
        SOUND_POWER_SAVE_ON_AC = 0;

        # BAT
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
        CPU_DRIVER_OPMODE_ON_BAT = "active";
        CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";
        CPU_SCALING_MIN_FREQ_ON_BAT = 400000;
        CPU_SCALING_MAX_FREQ_ON_BAT = 3500000;        # soft cap; use set-cpu-mode for explicit overrides
        CPU_BOOST_ON_BAT = 1;
        PLATFORM_PROFILE_ON_BAT = "balanced";
        SCHED_POWERSAVE_ON_BAT = 0;                    # scx_lavd schedules; HT disabled, consolidation hurts
        PCIE_ASPM_ON_BAT = "powersave";
        SATA_LINKPWR_ON_BAT = "min_power";
        AHCI_RUNTIME_PM_ON_BAT = "auto";
        RUNTIME_PM_ON_BAT = "auto";
        # Thunderbolt + downstream xHCI enter D3cold under runtime PM and
        # fail to resume, killing USB. Exclude their drivers so these devices
        # stay in D0 at runtime.
        RUNTIME_PM_DRIVER_DENYLIST = "thunderbolt xhci_hcd";
        WIFI_PWR_ON_BAT = "off";          # keep WiFi responsive; latency spikes tank browser perf
        SOUND_POWER_SAVE_ON_BAT = 60;
        SOUND_POWER_SAVE_CONTROLLER = "Y";

        # Battery health thresholds (BAT1: SANYO 01AV425).
        START_CHARGE_THRESH_BAT1 = 20;
        STOP_CHARGE_THRESH_BAT1 = 80;

        # USB autosuspend (internal keyboard is PS/2; unaffected).
        USB_AUTOSUSPEND = 1;
        USB_AUTOSUSPEND_DISABLE_ON_SHUTDOWN = 1;
        USB_DENYLIST = "046d:c547 1949:9981";  # Logitech G502X wireless receiver; Kindle Scribe (MTP breaks under autosuspend)
        USB_EXCLUDE_BTUSB = 1;
        USB_EXCLUDE_AUDIO = 1;
        USB_EXCLUDE_PHONE = 1;

        DEVICES_TO_DISABLE_ON_BAT_NOT_IN_USE = "bluetooth wwan";

        DISK_APM_LEVEL_ON_AC = "254";
        DISK_APM_LEVEL_ON_BAT = "128";
        DISK_SPINDOWN_TIMEOUT_ON_BAT = "1";
        DISK_IOSCHED = "none mq-deadline";  # none for NVMe (own NCQ), mq-deadline for any SATA

        WOL_DISABLE = "Y";
      };
    };
  };
}
