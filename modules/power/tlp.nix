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
        #
        # iwlwifi joined the list 2026-08-22 after the same failure mode hit
        # the AX210: on the first S3 resume without pcie_port_pm=off the card
        # came back inaccessible (MMIO reads all-0xff, AER Uncorrectable
        # Fatal / Inaccessible). iwlwifi registers no error_detected AER
        # callback, so the kernel cannot reset it; NetworkManager then spun
        # in iwl_poll_bits_mask inside ieee80211_open while holding RTNL,
        # which is unkillable and wedged shutdown into a force power-off.
        RUNTIME_PM_DRIVER_DENYLIST = "thunderbolt xhci_hcd iwlwifi";
        WIFI_PWR_ON_BAT = "off";          # keep WiFi responsive; latency spikes tank browser perf
        SOUND_POWER_SAVE_ON_BAT = 60;
        SOUND_POWER_SAVE_CONTROLLER = "Y";

        # Battery health thresholds. Both packs are LGC: BAT0 is the internal
        # 01AV420 (~24Wh Li-poly), BAT1 the removable Power Bridge 01AV427
        # (~80Wh Li-ion). The EC only initiates charge below START, so a plug-in
        # above START leaves the pack idle until it drops below it, then tops up
        # to STOP.
        #
        # BAT0 was previously unmanaged and rode the EC default of 96/100, which
        # holds the internal Li-poly at ~100% permanently; that is the worst
        # state for calendar ageing, and it sits next to a CPU that idles in the
        # 60s C. 75/80 costs ~5Wh of hot-swap reserve (still minutes of runtime,
        # far more than a Power Bridge swap needs) and matches BAT1's stop point.
        # Charge order is BAT0 first, then BAT1.
        START_CHARGE_THRESH_BAT0 = 75;
        STOP_CHARGE_THRESH_BAT0 = 80;
        START_CHARGE_THRESH_BAT1 = 20;
        STOP_CHARGE_THRESH_BAT1 = 80;

        # USB autosuspend (internal keyboard is PS/2; unaffected).
        USB_AUTOSUSPEND = 1;
        USB_AUTOSUSPEND_DISABLE_ON_SHUTDOWN = 1;
        USB_DENYLIST = "046d:c547 1949:9981";  # Logitech G502X wireless receiver; Kindle Scribe (MTP breaks under autosuspend)
        USB_EXCLUDE_BTUSB = 1;
        USB_EXCLUDE_AUDIO = 1;
        USB_EXCLUDE_PHONE = 1;

        # Bluetooth is controlled by the waybar bt toggle, not TLP; don't let
        # TLP flip it back when idle on battery.
        DEVICES_TO_DISABLE_ON_BAT_NOT_IN_USE = "wwan";

        # No DISK_APM_LEVEL / DISK_SPINDOWN: root is NVMe (no platters); ATA APM
        # and spindown are HDD-only no-ops. NVMe PM rides RUNTIME_PM + ASPM above.
        DISK_IOSCHED = "none mq-deadline";  # none for NVMe (own NCQ), mq-deadline for any SATA

        WOL_DISABLE = "Y";
      };
    };
  };
}
