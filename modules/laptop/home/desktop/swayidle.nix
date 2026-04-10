{ pkgs, ... }:

{
  # Automatic screen blanking and suspend for battery savings
  services.swayidle = {
    enable = true;
    systemdTarget = "sway-session.target";

    timeouts = [
      # Dim screen after 2 minutes (sets to 10% brightness)
      {
        timeout = 120;
        command = "${pkgs.brightnessctl}/bin/brightnessctl -s set 10%";
        resumeCommand = "${pkgs.brightnessctl}/bin/brightnessctl -r";
      }
      # Turn off screen after 3 minutes
      {
        timeout = 180;
        command = "${pkgs.sway}/bin/swaymsg 'output * power off'";
        resumeCommand = "${pkgs.sway}/bin/swaymsg 'output * power on'";
      }
      # Suspend after 10 minutes of idle
      {
        timeout = 600;
        command = "${pkgs.systemd}/bin/systemctl suspend";
      }
    ];

    events = [
      # Turn screen back on after resume
      {
        event = "after-resume";
        command = "${pkgs.sway}/bin/swaymsg 'output * power on'";
      }
    ];
  };

  # Minimal swaylock config
  programs.swaylock = {
    enable = false;
    settings = {
      color = "000000";
      show-failed-attempts = true;
    };
  };
}
