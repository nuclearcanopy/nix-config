{ pkgs, username, ... }:

let
  setCpuMode = pkgs.writeShellScriptBin "set-cpu-mode" ''
    set -euo pipefail
    case "''${1:-}" in
      spd)
        for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
          printf 'performance' > "$f"
        done
        for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq; do
          cat /sys/devices/system/cpu/"$(basename "$(dirname "$f")")/cpufreq/cpuinfo_max_freq" > "$f" 2>/dev/null || true
        done
        printf '0' > /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || true
        ;;
      bal)
        for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
          printf 'powersave' > "$f"
        done
        for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq; do
          cat /sys/devices/system/cpu/"$(basename "$(dirname "$f")")/cpufreq/cpuinfo_max_freq" > "$f" 2>/dev/null || true
        done
        printf '0' > /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || true
        ;;
      lap)
        for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
          printf 'powersave' > "$f"
        done
        printf '1' > /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || true
        for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq; do
          printf '2000000' > "$f"
        done
        ;;
      *)
        printf 'Usage: set-cpu-mode {spd|bal|lap}\n' >&2
        exit 1
        ;;
    esac
  '';
in

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

  environment.systemPackages = [ pkgs.powertop setCpuMode ];

  # Make CPU freq sysfs files group-writable by wheel at boot so the waybar
  # thermal toggle can write directly without sudo.
  users.users.${username}.extraGroups = [ "wheel" ];
  systemd.services.cpu-freq-perms = {
    description = "Allow wheel group to write CPU frequency sysfs files";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-udevd.service" ];
    serviceConfig.Type = "oneshot";
    script = ''
      for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor \
               /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq; do
        chgrp wheel "$f" && chmod g+w "$f" || true
      done
      if [ -f /sys/devices/system/cpu/intel_pstate/no_turbo ]; then
        chgrp wheel /sys/devices/system/cpu/intel_pstate/no_turbo
        chmod g+w /sys/devices/system/cpu/intel_pstate/no_turbo
      fi
    '';
  };

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
      # T480 has dual batteries (external BAT0 + internal BAT1)
      START_CHARGE_THRESH_BAT0 = 20;
      STOP_CHARGE_THRESH_BAT0 = 80;
      START_CHARGE_THRESH_BAT1 = 20;
      STOP_CHARGE_THRESH_BAT1 = 80;

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

  # Allow wheel users to run tlp chargeonce without a password (waybar CHG button)
  security.sudo.extraRules = [{
    groups = [ "wheel" ];
    commands = [{
      command = "${pkgs.tlp}/bin/tlp chargeonce *";
      options = [ "NOPASSWD" ];
    }];
  }];

  # ThinkPad firmware updates via LVFS
  services.fwupd.enable = true;

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
