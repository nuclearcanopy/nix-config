{
  # set-cpu-mode {spd|bal|lap|god|auto} + cpu-mode-restore service.
  # State file at /var/lib/cpu-mode/state records the last explicit mode;
  # cpu-mode-restore re-applies it after any event TLP also reacts to
  # (boot, AC/BAT change, resume), so god mode survives plug/unplug.
  # `auto` empties the state file and lets TLP drive again.
  nixos.modules.cpu-modes = { pkgs, username, ... }:

    let
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

        printf '%s\n' "$mode" > ${cpuModeStateFile}
      '';

      cpuModeRestore = pkgs.writeShellScript "cpu-mode-restore" ''
        set -eu
        [ -s ${cpuModeStateFile} ] || exit 0
        mode="$(cat ${cpuModeStateFile})"
        [ -n "$mode" ] || exit 0
        # TLP reacts to the same udev event in parallel; let it settle before
        # we overwrite governor/EPP. 0.5s is comfortable; TLP writes complete in ms.
        sleep 0.5
        exec ${setCpuMode}/bin/set-cpu-mode "$mode"
      '';
    in
    {
      # 4ms = 250Hz: middle ground between input latency and USB interrupt load.
      # Logitech receiver default is 1ms (1000Hz); 8ms = 125Hz felt laggy.
      boot.extraModprobeConfig = "options usbhid mousepoll=4";

      environment.systemPackages = [ pkgs.powertop setCpuMode ];

      # udev rules:
      # 1. XHC (USB xHCI, 0000:00:14.0) wakeup disable.
      # 2. CPU/RAPL sysfs write permissions for wheel group, so set-cpu-mode
      #    works without root from waybar. Shell logic lives in store scripts;
      #    udev's rule validator rejects $VAR inside RUN strings.
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

      # State dir must exist before set-cpu-mode (run by waybar as user) tries
      # to write to it. wheel-writable so user invocations succeed without root.
      systemd.tmpfiles.rules = [
        "d /var/lib/cpu-mode 0775 root wheel - -"
        "f ${cpuModeStateFile} 0664 root wheel - -"
      ];

      # Re-asserts the last explicit CPU mode after events TLP also reacts to:
      # boot (After=tlp.service), AC/BAT change (udev rule above), resume from
      # suspend. No-op if state is empty.
      systemd.services.cpu-mode-restore = {
        description = "Restore last explicit CPU performance mode";
        after = [ "tlp.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${cpuModeRestore}";
        };
      };
    };
}
