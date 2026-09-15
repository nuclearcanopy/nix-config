{
  # Suspend behavior: lid switch + power key suspend, idle suspend at 15min.
  # powerDownCommands tears the AX210 driver down before S3; resumeCommands
  # brings it back and handles the spurious-wake mitigation, backlight redraw,
  # waybar refresh signal, and Logitech receiver re-auth.
  nixos.modules.power-suspend = { pkgs, username, ... }: {
    services.logind.settings.Login = {
      HandleLidSwitch = "suspend";
      HandleLidSwitchExternalPower = "suspend";
      HandlePowerKey = "suspend";
      IdleAction = "suspend";
      IdleActionSec = "15min";
    };

    # AX210 (0000:01:00.0) stale-DMA-on-resume workaround.
    #
    # On roughly 1 in 10 S3 resumes the card replays a DMA read against an
    # address whose IOMMU mapping was not restored. iommu.strict=1 hard-faults
    # it ("DMAR: [DMA Read NO_PASID] Request device [01:00.0] ... [fault reason
    # 0x06] PTE Read access is not set"), the device drops off the bus with an
    # AER Uncorrectable (Fatal) / Inaccessible, every MMIO read returns 0xff,
    # and because iwlwifi registers no error_detected AER callback the kernel
    # cannot reset it. wlp1s0 disappears and `nmcli dev wifi list` is empty
    # until reboot. Seen 2026-09-09 13:51 and 2026-09-11 11:46; in both the
    # DMAR fault precedes the AER error, so the IOMMU fault is the trigger,
    # not a consequence of the card already being dead.
    #
    # Unloading the driver before S3 makes it release its DMA mappings cleanly,
    # so there is nothing stale left to replay on resume. iwlwifi.remove_when_gone
    # and the TLP iwlwifi runtime-PM denylist stay as-is: they limit the damage
    # (no RTNL wedge) but never fired the removal path, so they do not recover
    # the card on their own.
    #
    # Skipped while the radio is rfkill-blocked: systemd-rfkill is masked on
    # this host, so a reload would come back soft-unblocked and silently undo
    # the waybar airgap toggle. A blocked radio is also not moving traffic, so
    # it is not the DMA source. The flag file is set before the unload is
    # attempted so a partial unload (iwlmvm gone, iwlwifi stuck) still gets
    # repaired on resume rather than leaving the card with no opmode driver.
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
        if [ "$v" = "046d" ] && [ "$p" = "c547" ]; then
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
