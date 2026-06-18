{
  # Suspend behavior: lid switch + power key suspend, idle suspend at 15min.
  # resumeCommands handles the spurious-wake mitigation, backlight redraw,
  # waybar refresh signal, and Logitech receiver re-auth.
  nixos.modules.power-suspend = { pkgs, username, ... }: {
    services.logind.settings.Login = {
      HandleLidSwitch = "suspend";
      HandleLidSwitchExternalPower = "suspend";
      HandlePowerKey = "suspend";
      IdleAction = "suspend";
      IdleActionSec = "15min";
    };

    # Re-suspend if the lid is still closed 30s after waking.
    # The T480 lid Hall-effect sensor can fire a spurious "lid opened" ACPI
    # event from bag pressure/movement, waking the machine while the lid is
    # physically closed. Without this the machine can run hot in a bag for
    # hours if a Wayland idle inhibitor (e.g. Steam) blocks swayidle's
    # 10-min fallback. XHC wakeup is handled via udev in the cpu-modes bucket.
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
  };
}
