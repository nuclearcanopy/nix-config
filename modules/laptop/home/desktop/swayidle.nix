{ pkgs, ... }:

let
  # AC-aware idle script: aggressive on battery, relaxed on AC
  idleCmd = timeout: batCmd: acCmd: {
    inherit timeout;
    command = toString (pkgs.writeShellScript "swayidle-${toString timeout}" ''
      if [ "$(cat /sys/class/power_supply/AC0/online 2>/dev/null || cat /sys/class/power_supply/ACAD/online 2>/dev/null || echo 0)" = "1" ]; then
        ${acCmd}
      else
        ${batCmd}
      fi
    '');
  };
in
{
  services.swayidle = {
    enable = true;
    systemdTarget = "sway-session.target";

    timeouts = [
      # 60s: dim on battery, nothing on AC
      ((idleCmd 60
        "${pkgs.brightnessctl}/bin/brightnessctl -s set 10%"
        "true"
      ) // {
        resumeCommand = "${pkgs.brightnessctl}/bin/brightnessctl -r";
      })
      # 2min: screen off on battery, nothing on AC
      ((idleCmd 120
        "${pkgs.sway}/bin/swaymsg 'output * power off'"
        "true"
      ) // {
        resumeCommand = "${pkgs.sway}/bin/swaymsg 'output * power on'";
      })
      # 5min on battery / 30min on AC: suspend
      {
        timeout = 300;
        command = toString (pkgs.writeShellScript "swayidle-suspend" ''
          if [ "$(cat /sys/class/power_supply/AC0/online 2>/dev/null || cat /sys/class/power_supply/ACAD/online 2>/dev/null || echo 0)" = "1" ]; then
            # On AC: only suspend after 30 minutes (handled by the 1800s timeout below)
            true
          else
            ${pkgs.systemd}/bin/systemctl suspend
          fi
        '');
      }
      # 30min: suspend even on AC
      {
        timeout = 1800;
        command = "${pkgs.systemd}/bin/systemctl suspend";
      }
    ];

    events = [
      {
        event = "after-resume";
        command = "${pkgs.sway}/bin/swaymsg 'output * power on'";
      }
    ];
  };

  programs.swaylock = {
    enable = false;
    settings = {
      color = "000000";
      show-failed-attempts = true;
    };
  };
}
