{
  # AC-aware swayidle + swaylock. On battery: dim at 60s, screen off at 2min.
  # On AC: screen off at 5min. Both states: lock-then-suspend at 10min.
  # before-sleep locks the screen so the wake-from-suspend session is protected.
  homeManager.modules.swayidle = { pkgs, ... }: {
    services.swayidle = {
      enable = true;
      systemdTargets = [ "sway-session.target" ];

      timeouts = [
        {
          timeout = 60;
          command = toString (pkgs.writeShellScript "swayidle-dim" ''
            if [ "$(cat /sys/class/power_supply/AC/online 2>/dev/null || echo 0)" = "1" ]; then
              true
            else
              ${pkgs.brightnessctl}/bin/brightnessctl -s set 10%
            fi
          '');
          resumeCommand = "${pkgs.brightnessctl}/bin/brightnessctl -r";
        }
        {
          timeout = 120;
          command = toString (pkgs.writeShellScript "swayidle-screenoff-bat" ''
            if [ "$(cat /sys/class/power_supply/AC/online 2>/dev/null || echo 0)" = "1" ]; then
              true
            else
              ${pkgs.sway}/bin/swaymsg 'output * power off'
            fi
          '');
          resumeCommand = "${pkgs.sway}/bin/swaymsg 'output * power on'";
        }
        {
          timeout = 300;
          command = toString (pkgs.writeShellScript "swayidle-screenoff-ac" ''
            if [ "$(cat /sys/class/power_supply/AC/online 2>/dev/null || echo 0)" = "1" ]; then
              ${pkgs.sway}/bin/swaymsg 'output * power off'
            else
              true
            fi
          '');
          resumeCommand = "${pkgs.sway}/bin/swaymsg 'output * power on'";
        }
        {
          timeout = 600;
          command = "${pkgs.systemd}/bin/systemctl suspend";
        }
      ];

      events = {
        # Do NOT call `brightnessctl -s` here. If the screen is already dimmed
        # by the 60s idle handler, saving now would overwrite the pre-dim
        # value with the dimmed value and after-resume would restore dim.
        before-sleep = "${pkgs.swaylock}/bin/swaylock -f -c 000000";
        after-resume = toString (pkgs.writeShellScript "swayidle-after-resume" ''
          ${pkgs.sway}/bin/swaymsg 'output * power on'
          # Restore the user's persisted brightness, not the dim value.
          f=/var/lib/screen-brightness/value
          if [ -r "$f" ]; then
            val=$(cat "$f")
            if [ -n "$val" ] && [ "$val" -eq "$val" ] 2>/dev/null; then
              ${pkgs.brightnessctl}/bin/brightnessctl set "''${val}%" >/dev/null || true
            fi
          else
            ${pkgs.brightnessctl}/bin/brightnessctl -r >/dev/null || true
          fi
        '');
      };
    };

    programs.swaylock = {
      enable = true;
      settings = {
        color = "000000";
        show-failed-attempts = true;
        indicator-idle-visible = true;
        indicator-radius = 60;
        indicator-thickness = 4;
        ring-color = "444444ff";
        inside-color = "00000000";
        line-color = "00000000";
        key-hl-color = "ffffffff";
        bs-hl-color = "ff4444ff";
        text-color = "00000000";
        ring-ver-color = "4488ffff";
        ring-wrong-color = "ff4444ff";
        inside-ver-color = "00000000";
        inside-wrong-color = "00000000";
      };
    };
  };
}
