{ pkgs, ... }:

{
  services.swayidle = {
    enable = true;
    systemdTarget = "sway-session.target";

    timeouts = [
      # 60s: dim on battery, nothing on AC
      {
        timeout = 60;
        command = toString (pkgs.writeShellScript "swayidle-dim" ''
          if [ "$(cat /sys/class/power_supply/AC0/online 2>/dev/null || cat /sys/class/power_supply/ACAD/online 2>/dev/null || echo 0)" = "1" ]; then
            true
          else
            ${pkgs.brightnessctl}/bin/brightnessctl -s set 10%
          fi
        '');
        resumeCommand = "${pkgs.brightnessctl}/bin/brightnessctl -r";
      }
      # 2min: screen off on battery, nothing on AC
      {
        timeout = 120;
        command = toString (pkgs.writeShellScript "swayidle-screenoff-bat" ''
          if [ "$(cat /sys/class/power_supply/AC0/online 2>/dev/null || cat /sys/class/power_supply/ACAD/online 2>/dev/null || echo 0)" = "1" ]; then
            true
          else
            ${pkgs.sway}/bin/swaymsg 'output * power off'
          fi
        '');
        resumeCommand = "${pkgs.sway}/bin/swaymsg 'output * power on'";
      }
      # 5min: screen off on AC
      {
        timeout = 300;
        command = toString (pkgs.writeShellScript "swayidle-screenoff-ac" ''
          if [ "$(cat /sys/class/power_supply/AC0/online 2>/dev/null || cat /sys/class/power_supply/ACAD/online 2>/dev/null || echo 0)" = "1" ]; then
            ${pkgs.sway}/bin/swaymsg 'output * power off'
          else
            true
          fi
        '');
        resumeCommand = "${pkgs.sway}/bin/swaymsg 'output * power on'";
      }
      # 10min: suspend (both AC and battery).
      # The luks-suspend systemd service wipes the LUKS key before sleep,
      # and before-sleep locks the screen so userspace is also protected.
      {
        timeout = 600;
        command = "${pkgs.systemd}/bin/systemctl suspend";
      }
    ];

    events = [
      # Lock screen before any suspend so the session is protected on wake.
      # The LUKS key is wiped separately by the luks-suspend systemd service.
      {
        event = "before-sleep";
        command = "${pkgs.swaylock}/bin/swaylock -f -c 000000";
      }
      {
        event = "after-resume";
        command = "${pkgs.sway}/bin/swaymsg 'output * power on'";
      }
    ];
  };

  programs.swaylock = {
    enable = true;
    settings = {
      color = "000000";
      show-failed-attempts = true;
    };
  };
}
