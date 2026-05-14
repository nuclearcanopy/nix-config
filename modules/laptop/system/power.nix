{ pkgs, username, ... }:

let
  setCpuMode = pkgs.writeShellScriptBin "set-cpu-mode" ''
    set -euo pipefail

    cpu_write() { # field value [ignore?]
      local field="$1" value="$2" ignore="''${3:-}"
      for f in /sys/devices/system/cpu/cpu*/"cpufreq/$field"; do
        if [ -n "$ignore" ]; then
          printf '%s' "$value" > "$f" 2>/dev/null || true
        else
          printf '%s' "$value" > "$f"
        fi
      done
    }
    no_turbo() { printf '%s' "$1" > /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || true; }
    rapl_write() { printf '%s' "$2" > /sys/devices/virtual/powercap/intel-rapl/intel-rapl:0/"$1" 2>/dev/null || true; }

    case "''${1:-}" in
      spd) cpu_write scaling_governor performance ignore
           cpu_write energy_performance_preference performance ignore
           cpu_write scaling_max_freq 3600000 ignore
           no_turbo 0 ;;
      bal) cpu_write scaling_governor powersave ignore
           cpu_write energy_performance_preference power ignore
           cpu_write scaling_max_freq 3000000 ignore
           no_turbo 1 ;;
      lap) cpu_write scaling_governor powersave ignore
           cpu_write energy_performance_preference power ignore
           cpu_write scaling_max_freq 2000000 ignore
           no_turbo 1 ;;
      god) cpu_write scaling_governor performance ignore
           cpu_write energy_performance_preference performance ignore
           cpu_write scaling_max_freq 3600000 ignore
           no_turbo 0
           rapl_write constraint_0_power_limit_uw 45000000
           rapl_write constraint_1_power_limit_uw 60000000
           printf 'GOD MODE: turbo on, 3.6GHz, PL1=45W PL2=60W\n' ;;
      *)   printf 'Usage: set-cpu-mode {spd|bal|lap|god}\n' >&2; exit 1 ;;
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
    after = [ "systemd-udevd.service" "tlp.service" ];
    serviceConfig.Type = "oneshot";
    script = ''
      for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor \
               /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq \
               /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
        chgrp wheel "$f" && chmod g+w "$f" || true
      done
      if [ -f /sys/devices/system/cpu/intel_pstate/no_turbo ]; then
        chgrp wheel /sys/devices/system/cpu/intel_pstate/no_turbo
        chmod g+w /sys/devices/system/cpu/intel_pstate/no_turbo
      fi
      for f in /sys/devices/virtual/powercap/intel-rapl/intel-rapl:0/constraint_0_power_limit_uw \
               /sys/devices/virtual/powercap/intel-rapl/intel-rapl:0/constraint_1_power_limit_uw; do
        [ -f "$f" ] && chgrp wheel "$f" && chmod g+w "$f" || true
      done
    '';
  };

  services.tlp = {
    enable = true;
    settings = {
      # ═══════════════════════════════════════════════════════════════════
      # AC MODE — full performance, no limits
      # ═══════════════════════════════════════════════════════════════════
      CPU_SCALING_GOVERNOR_ON_AC = "powersave";
      CPU_DRIVER_OPMODE_ON_AC = "active";
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_SCALING_MIN_FREQ_ON_AC = 400000;
      CPU_SCALING_MAX_FREQ_ON_AC = 3600000;        # i5-8350U turbo max — don't exceed or TLP write fails
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
      CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";
      CPU_SCALING_MIN_FREQ_ON_BAT = 400000;
      CPU_SCALING_MAX_FREQ_ON_BAT = 3500000;        # soft cap — use lap for battery saver, spd for full turbo
      CPU_BOOST_ON_BAT = 1;
      PLATFORM_PROFILE_ON_BAT = "balanced";
      SCHED_POWERSAVE_ON_BAT = 1;                    # scx_lavd handles responsiveness
      PCIE_ASPM_ON_BAT = "powersupersave";
      SATA_LINKPWR_ON_BAT = "min_power";
      AHCI_RUNTIME_PM_ON_BAT = "auto";
      RUNTIME_PM_ON_BAT = "auto";
      WIFI_PWR_ON_BAT = "off";          # keep WiFi responsive — latency spikes tank browser perf
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

  # CPU undervolting — i5-8350U (Kaby Lake-R), BIOS N24ET81W 1.56
  # Start conservative; go deeper if stable under stress-ng.
  # WARNING: if system crashes/freezes, reduce offsets and rebuild.
  services.undervolt = {
    enable = true;
    coreOffset    = -115;  # CPU cores
    gpuOffset     = -45;   # Intel UHD 620
    uncoreOffset  = -115;  # CPU cache / ring bus
    analogioOffset = 0;    # leave alone
  };

  # ThinkPad firmware updates via LVFS
  services.fwupd.enable = true;

  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "suspend";
    HandlePowerKey = "suspend";
    IdleAction = "suspend";
    IdleActionSec = "15min";
  };

  # XHC (USB xHCI controller, 0000:00:14.0) is enabled as a S3 wakeup source
  # by firmware. Any USB event (trackpad, keyboard, internal hub) causes an
  # immediate spurious resume after lid-close suspend, draining the battery.
  # Disable it at boot and re-disable after every resume (firmware re-enables it).
  systemd.services.disable-xhc-wakeup = {
    description = "Disable USB xHCI S3 wakeup to prevent spurious resume";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-udevd.service" ];
    serviceConfig.Type = "oneshot";
    script = ''
      echo disabled > /sys/bus/pci/devices/0000:00:14.0/power/wakeup || true
    '';
  };

  powerManagement.resumeCommands = ''
    echo disabled > /sys/bus/pci/devices/0000:00:14.0/power/wakeup || true
  '';

  # Relaxed fan curve — fans stay off until 68°C, then ramp up gradually.
  # The module auto-enables thinkpad_acpi fan_control=1.
  services.thinkfan = {
    enable = true;
    levels = [
      # [ level  low  high ]
      [ 0    0   65 ]   # off until 65°C
      [ 1   62   72 ]   # barely audible, slow creep in
      [ 2   70   75 ]
      [ 3   73   79 ]
      [ 5   77   83 ]
      [ 7   81   32767 ] # full speed above 81°C
    ];
  };
}
