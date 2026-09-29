{
  # Suspend behavior: lid switch + power key suspend, idle suspend at 15min.
  # powerDownCommands tears the AX210 driver down before S3; resumeCommands
  # brings it back and handles the spurious-wake mitigation, backlight redraw,
  # waybar refresh signal, and Logitech receiver re-auth.
  nixos.modules.power-suspend =
    let
      usbIds = import ../hardware/usb-ids.data.nix;
    in
    { pkgs, username, ... }: {
    services.logind.settings.Login = {
      HandleLidSwitch = "suspend";
      HandleLidSwitchExternalPower = "suspend";
      HandlePowerKey = "suspend";
      IdleAction = "suspend";
      IdleActionSec = "15min";
    };

    # AX210 (0000:01:00.0) stale-DMA-on-resume workaround: unload the driver
    # before S3 so it has no stale DMA mapping to replay on resume. Skipped
    # while the radio is rfkill-blocked (a reload would come back unblocked).
    # Full incident history: docs/power.md#ax210-resume-from-s3-failures
    powerManagement.powerDownCommands = ''
      wlan_blocked=no
      for r in /sys/class/rfkill/rfkill*; do
        [ "$(cat "$r/type" 2>/dev/null)" = "wlan" ] || continue
        [ "$(cat "$r/soft" 2>/dev/null)" = "0" ] || wlan_blocked=yes
        [ "$(cat "$r/hard" 2>/dev/null)" = "0" ] || wlan_blocked=yes
      done
      if [ "$wlan_blocked" = "no" ] && [ -d /sys/module/iwlwifi ]; then
        touch /run/iwlwifi-sleep-unloaded || true
        ${pkgs.kmod}/bin/modprobe -r iwlmvm 2>/dev/null || true
        ${pkgs.kmod}/bin/modprobe -r iwlwifi 2>/dev/null || true
      fi
    '';

    # Re-suspend if the lid is still closed 30s after waking.
    # The T480 lid Hall-effect sensor can fire a spurious "lid opened" ACPI
    # event from bag pressure/movement, waking the machine while the lid is
    # physically closed. Without this the machine can run hot in a bag for
    # hours if a Wayland idle inhibitor (e.g. Steam) blocks swayidle's
    # 10-min fallback. XHC wakeup is handled via udev in the cpu-modes bucket.
    powerManagement.resumeCommands = ''
      # Reload the AX210 driver torn down in powerDownCommands. Both modprobes
      # are idempotent; iwlmvm is normally auto-requested as the opmode module
      # when iwlwifi probes the device, and is repeated here only to cover the
      # partial-unload case.
      if [ -e /run/iwlwifi-sleep-unloaded ]; then
        rm -f /run/iwlwifi-sleep-unloaded || true
        ${pkgs.kmod}/bin/modprobe iwlwifi 2>/dev/null || true
        ${pkgs.kmod}/bin/modprobe iwlmvm 2>/dev/null || true
      fi
      ( sleep 30
        if grep -q "closed" /proc/acpi/button/lid/LID/state 2>/dev/null; then
          systemctl suspend
        fi
      ) &
      systemctl start --no-block cpu-mode-restore.service || true
      ${pkgs.procps}/bin/pkill -u ${username} --signal 43 waybar || true
      for b in /sys/class/backlight/*/brightness; do
        [ -f "$b" ] && val=$(cat "$b") && echo "$val" > "$b" 2>/dev/null || true
      done
      for devdir in /sys/bus/usb/devices/*/; do
        # The glob also matches interface dirs (e.g. 1-0:1.0/) which have no
        # idVendor. Without `|| continue` the failed assignment trips `set -e`
        # in the generated script and aborts the whole resume hook.
        v=$(cat "$devdir/idVendor" 2>/dev/null) || continue
        p=$(cat "$devdir/idProduct" 2>/dev/null) || continue
        if [ "$v" = "${usbIds.logitechG502XReceiver.vendor}" ] && [ "$p" = "${usbIds.logitechG502XReceiver.product}" ]; then
          echo 0 > "$devdir/authorized" 2>/dev/null || true
          sleep 0.5
          echo 1 > "$devdir/authorized" 2>/dev/null || true
          # Re-authorizing is a USB remove+add, so waybar's mouse battery is
          # unreadable for a moment and its own poll is 5 minutes away. Give
          # the receiver time to re-enumerate and re-acquire its uaccess ACL,
          # then poke custom/mouse (signal 13 = SIGRTMIN+13).
          ( sleep 5
            ${pkgs.procps}/bin/pkill -u ${username} --signal 47 waybar
          ) >/dev/null 2>&1 &
          break
        fi
      done
    '';
  };
}
