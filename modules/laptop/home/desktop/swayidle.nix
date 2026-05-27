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
          if [ "$(cat /sys/class/power_supply/AC/online 2>/dev/null || echo 0)" = "1" ]; then
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
          if [ "$(cat /sys/class/power_supply/AC/online 2>/dev/null || echo 0)" = "1" ]; then
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
          if [ "$(cat /sys/class/power_supply/AC/online 2>/dev/null || echo 0)" = "1" ]; then
            ${pkgs.sway}/bin/swaymsg 'output * power off'
          else
            true
          fi
        '');
        resumeCommand = "${pkgs.sway}/bin/swaymsg 'output * power on'";
      }
      # 10min: suspend (both AC and battery).
      {
        timeout = 600;
        command = "${pkgs.systemd}/bin/systemctl suspend";
      }
    ];

    events = [
      # Lock screen before any suspend so the session is protected on wake.
      {
        event = "before-sleep";
        command = "${pkgs.brightnessctl}/bin/brightnessctl -s; ${pkgs.swaylock}/bin/swaylock -f -c 000000";
      }
      {
        event = "after-resume";
        command = toString (pkgs.writeShellScript "swayidle-after-resume" ''
          ${pkgs.sway}/bin/swaymsg 'output * power on'
          ${pkgs.brightnessctl}/bin/brightnessctl -r
          val=$(${pkgs.brightnessctl}/bin/brightnessctl g)
          ${pkgs.brightnessctl}/bin/brightnessctl s "$val"
        '');
      }
    ];
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
}
