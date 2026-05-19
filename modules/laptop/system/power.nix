{ pkgs, ... }:

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
           no_turbo 0
           rapl_write constraint_0_power_limit_uw 25000000
           rapl_write constraint_1_power_limit_uw 29000000 ;;
      bal) cpu_write scaling_governor powersave ignore
           cpu_write energy_performance_preference power ignore
           cpu_write scaling_max_freq 3000000 ignore
           no_turbo 0
           rapl_write constraint_0_power_limit_uw 25000000
           rapl_write constraint_1_power_limit_uw 29000000 ;;
      lap) cpu_write scaling_governor powersave ignore
           cpu_write energy_performance_preference power ignore
           cpu_write scaling_max_freq 2000000 ignore
           no_turbo 1
           rapl_write constraint_0_power_limit_uw 15000000
           rapl_write constraint_1_power_limit_uw 20000000 ;;
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

  environment.systemPackages = [ pkgs.powertop setCpuMode ];

  # udev rules replace three boot services:
  # 1. Battery charge thresholds 20–80%: TLP can't apply them because Libreboot
  #    sets DMI product_version="1.0" (not "ThinkPad ..."), so TLP falls back to
  #    the generic plugin which doesn't support threshold management.
  # 2. XHC (USB xHCI, 0000:00:14.0) wakeup disable: fires on device appearance
  #    (boot + resume), replacing both the boot service and the resumeCommands entry.
  # 3. CPU/RAPL sysfs write permissions for wheel group, so set-cpu-mode works
  #    without root from waybar. Shell logic lives in store scripts — udev's rule
  #    validator rejects $VAR inside RUN strings (treats them as property refs).
  services.udev.extraRules =
    let
      cpuFreqPerms = pkgs.writeShellScript "cpu-freq-perms" ''
        for field in scaling_governor scaling_max_freq energy_performance_preference; do
          p="/sys$1/cpufreq/$field"
          [ -f "$p" ] && chgrp wheel "$p" && chmod g+w "$p" || true
        done
      '';
      intelPstatePerms = pkgs.writeShellScript "intel-pstate-perms" ''
        f=/sys/devices/system/cpu/intel_pstate/no_turbo
        [ -f "$f" ] && chgrp wheel "$f" && chmod g+w "$f" || true
      '';
      raplPerms = pkgs.writeShellScript "rapl-perms" ''
        for field in constraint_0_power_limit_uw constraint_1_power_limit_uw; do
          p="/sys$1/$field"
          [ -f "$p" ] && chgrp wheel "$p" && chmod g+w "$p" || true
        done
      '';
    in ''
      ACTION=="add", SUBSYSTEM=="power_supply", ATTR{type}=="Battery", ATTR{charge_control_start_threshold}=="?*", ATTR{charge_control_start_threshold}="20", ATTR{charge_control_end_threshold}="80"
      SUBSYSTEM=="pci", KERNEL=="0000:00:14.0", ATTR{power/wakeup}="disabled"
      ACTION=="add", SUBSYSTEM=="cpu", KERNEL=="cpu[0-9]*", RUN+="${cpuFreqPerms} %p"
      ACTION=="add", SUBSYSTEM=="cpu", KERNEL=="cpu0", RUN+="${intelPstatePerms}"
      ACTION=="add", SUBSYSTEM=="powercap", KERNEL=="intel-rapl:0", RUN+="${raplPerms} %p"
    '';

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
      SCHED_POWERSAVE_ON_BAT = 0;                    # scx_lavd handles scheduling; don't consolidate cores (worse with HT disabled)
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
      DISK_IOSCHED = "none mq-deadline";  # none for NVMe (has own NCQ), mq-deadline for any SATA

      WOL_DISABLE = "Y";
    };
  };

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

  # Re-suspend if the lid is still closed 30 s after waking.
  # The T480 lid Hall-effect sensor can fire a spurious "lid opened" ACPI
  # event from bag pressure/movement, waking the machine while the lid is
  # physically closed or quickly settles back closed. Without this, the
  # machine can run hot in a bag for hours if a Wayland idle inhibitor
  # (e.g. Steam) is also preventing swayidle's 10-min fallback.
  # XHC wakeup is handled declaratively via services.udev.extraRules above.
  powerManagement.resumeCommands = ''
    ( sleep 30
      if grep -q "closed" /proc/acpi/button/lid/LID/state 2>/dev/null; then
        systemctl suspend
      fi
    ) &
  '';

  # thinkfan disabled: thinkpad_acpi refuses to load under Libreboot (no OEM DMI).
  # The EC handles fan control autonomously as a hardware fallback.
  services.thinkfan.enable = false;
}
