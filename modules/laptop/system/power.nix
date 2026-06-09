{ pkgs, username, ... }:

let
  # State file records the last explicitly set mode. cpu-mode-restore.service
  # re-applies it after any event that TLP also reacts to (boot, AC/BAT change,
  # resume), so an explicit mode — especially god — survives TLP overwriting
  # governor/EPP. Empty/missing state means "let TLP drive".
  cpuModeStateFile = "/var/lib/cpu-mode/state";

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

    mode="''${1:-}"
    case "$mode" in
      spd) cpu_write scaling_governor performance ignore
           cpu_write energy_performance_preference performance ignore
           cpu_write scaling_max_freq 3600000 ignore
           no_turbo 0
           rapl_write constraint_0_power_limit_uw 25000000
           rapl_write constraint_1_power_limit_uw 29000000 ;;
      bal) cpu_write scaling_governor powersave ignore
           cpu_write energy_performance_preference balance_performance ignore
           cpu_write scaling_max_freq 3600000 ignore
           no_turbo 0
           rapl_write constraint_0_power_limit_uw 25000000
           rapl_write constraint_1_power_limit_uw 35000000 ;;
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
      auto) : >${cpuModeStateFile}
            printf 'CPU mode: auto (TLP-managed)\n'
            exit 0 ;;
      *)   printf 'Usage: set-cpu-mode {spd|bal|lap|god|auto}\n' >&2; exit 1 ;;
    esac

    # Persist so cpu-mode-restore can put it back after TLP fires.
    printf '%s\n' "$mode" > ${cpuModeStateFile}
  '';

  cpuModeRestore = pkgs.writeShellScript "cpu-mode-restore" ''
    set -eu
    [ -s ${cpuModeStateFile} ] || exit 0
    mode="$(cat ${cpuModeStateFile})"
    [ -n "$mode" ] || exit 0
    # TLP reacts to the same udev event in parallel; let it settle before we
    # overwrite governor/EPP. 0.5s is comfortable — TLP writes complete in ms.
    sleep 0.5
    exec ${setCpuMode}/bin/set-cpu-mode "$mode"
  '';
in

{
  # Logitech receiver default is 1ms (1000Hz); 8ms ≈ 125Hz saves USB interrupt overhead.
  boot.extraModprobeConfig = "options usbhid mousepoll=8";

  # TLP manages CPU frequency governors per AC/BAT state.
  # AC: full performance. Battery: maximum power savings.
  services.power-profiles-daemon.enable = false;

  environment.systemPackages = [ pkgs.powertop setCpuMode ];

  # udev rules:
  # 1. XHC (USB xHCI, 0000:00:14.0) wakeup disable: fires on device appearance
  #    (boot + resume).
  # 2. CPU/RAPL sysfs write permissions for wheel group, so set-cpu-mode works
  #    without root from waybar. Shell logic lives in store scripts — udev's rule
  #    validator rejects $VAR inside RUN strings (treats them as property refs).
  # Battery thresholds are managed by TLP after the Libreboot coreboot fix that
  # sets CONFIG_MAINBOARD_SMBIOS_PRODUCT_NAME="ThinkPad T480". TLP 1.8 has explicit
  # Libreboot support: when product_version lacks "ThinkPad" it falls back to
  # product_name. With the correct name, TLP uses its thinkpad plugin + natacpi.
  services.udev.extraRules =
    let
      makeWheelWritable = pkgs.writeShellScript "make-wheel-writable" ''
        for f in "$@"; do
          [ -f "$f" ] && chgrp wheel "$f" && chmod g+w "$f" || true
        done
      '';
    in ''
      SUBSYSTEM=="usb", ATTR{idVendor}=="1949", ATTR{idProduct}=="9981", MODE="0664", GROUP="users"
      SUBSYSTEM=="pci", KERNEL=="0000:00:14.0", ATTR{power/wakeup}="disabled"
      ACTION=="add", SUBSYSTEM=="cpu", KERNEL=="cpu[0-9]*", RUN+="${makeWheelWritable} /sys%p/cpufreq/scaling_governor /sys%p/cpufreq/scaling_max_freq /sys%p/cpufreq/energy_performance_preference"
      ACTION=="add", SUBSYSTEM=="cpu", KERNEL=="cpu0", RUN+="${makeWheelWritable} /sys/devices/system/cpu/intel_pstate/no_turbo"
      ACTION=="add", SUBSYSTEM=="powercap", KERNEL=="intel-rapl:0", RUN+="${makeWheelWritable} /sys%p/constraint_0_power_limit_uw /sys%p/constraint_1_power_limit_uw"
      SUBSYSTEM=="power_supply", ACTION=="change", RUN+="${pkgs.systemd}/bin/systemctl start --no-block cpu-mode-restore.service"
      SUBSYSTEM=="power_supply", ACTION=="change", RUN+="${pkgs.procps}/bin/pkill -u ${username} --signal 41 waybar"
    '';

  # State dir must exist before set-cpu-mode (run by the user via waybar) tries
  # to write to it. wheel-writable so user invocations succeed without root.
  systemd.tmpfiles.rules = [
    "d /var/lib/cpu-mode 0775 root wheel - -"
    "f ${cpuModeStateFile} 0664 root wheel - -"
  ];

  # Re-asserts the last explicit CPU mode after events that TLP also reacts to:
  # boot (After=tlp.service), AC/BAT change (udev rule above), resume from
  # suspend (powerManagement.resumeCommands below). No-op if state is empty.
  systemd.services.cpu-mode-restore = {
    description = "Restore last explicit CPU performance mode";
    after = [ "tlp.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${cpuModeRestore}";
    };
  };

  services.tlp = {
    enable = true;
    settings = {
      # ═══════════════════════════════════════════════════════════════════
      # AC MODE — adaptive: bursts to full turbo on demand, backs off at idle
      # Use set-cpu-mode spd/god for explicit high-performance work.
      # ═══════════════════════════════════════════════════════════════════
      CPU_SCALING_GOVERNOR_ON_AC = "powersave";
      CPU_DRIVER_OPMODE_ON_AC = "active";
      CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
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
      PCIE_ASPM_ON_BAT = "powersave";
      SATA_LINKPWR_ON_BAT = "min_power";
      AHCI_RUNTIME_PM_ON_BAT = "auto";
      RUNTIME_PM_ON_BAT = "auto";
      # Thunderbolt controller and its downstream xHCI (0000:04:00.0 / 0000:06:00.0)
      # enter D3cold under runtime PM and fail to resume, killing USB. Exclude their
      # drivers so these devices stay in D0 at runtime.
      RUNTIME_PM_DRIVER_DENYLIST = "thunderbolt xhci_hcd";
      WIFI_PWR_ON_BAT = "off";          # keep WiFi responsive — latency spikes tank browser perf
      SOUND_POWER_SAVE_ON_BAT = 60;
      SOUND_POWER_SAVE_CONTROLLER = "Y";

      # ═══════════════════════════════════════════════════════════════════
      # BATTERY HEALTH — thresholds for BAT1 (SANYO 01AV425, the only
      # battery on this machine). TLP uses thinkpad plugin + natacpi after
      # SMBIOS product_name was fixed to "ThinkPad T480" in Libreboot config.
      # Default without these would be 96/100 which is no protection at all.
      # ═══════════════════════════════════════════════════════════════════
      START_CHARGE_THRESH_BAT1 = 20;
      STOP_CHARGE_THRESH_BAT1 = 80;

      # ═══════════════════════════════════════════════════════════════════
      # SHARED / OTHER
      # ═══════════════════════════════════════════════════════════════════
      # USB autosuspend — enabled; internal keyboard is PS/2 (unaffected)
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
    systemctl start --no-block cpu-mode-restore.service || true
    pkill -u ${username} --signal 43 waybar || true
    for b in /sys/class/backlight/*/brightness; do
      [ -f "$b" ] && val=$(cat "$b") && echo "$val" > "$b" 2>/dev/null || true
    done
    for devdir in /sys/bus/usb/devices/*/; do
      v=$(cat "$devdir/idVendor" 2>/dev/null)
      p=$(cat "$devdir/idProduct" 2>/dev/null)
      if [ "$v" = "046d" ] && [ "$p" = "c547" ]; then
        echo 0 > "$devdir/authorized" 2>/dev/null || true
        sleep 0.5
        echo 1 > "$devdir/authorized" 2>/dev/null || true
        break
      fi
    done
  '';

  services.thinkfan = {
    enable = true;
    settings = {
      sensors = [
        {
          hwmon = "/sys/devices/platform/coretemp.0";
          indices = [ 1 2 3 4 5 ];
        }
      ];
      fans = [ { tpacpi = "/proc/acpi/ibm/fan"; } ];
      levels = [
        [ 0   0  55 ]
        [ 1  52  60 ]
        [ 2  57  65 ]
        [ 3  62  70 ]
        [ 5  67  75 ]
        [ 7  72 255 ]
      ];
    };
  };
}
