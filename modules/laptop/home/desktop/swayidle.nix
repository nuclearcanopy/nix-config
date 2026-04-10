{ pkgs, ... }:

{
  # Automatic screen blanking and suspend for battery savings
  services.swayidle = {
    enable = true;
    systemdTarget = "sway-session.target";

    timeouts = [
      # Dim screen after 1 minute (sets to 10% brightness)
      {
        timeout = 60;
        command = "${pkgs.brightnessctl}/bin/brightnessctl -s set 10%";
        resumeCommand = "${pkgs.brightnessctl}/bin/brightnessctl -r";
      }
      # Turn off screen after 2 minutes
      {
        timeout = 120;
        command = "${pkgs.sway}/bin/swaymsg 'output * power off'";
        resumeCommand = "${pkgs.sway}/bin/swaymsg 'output * power on'";
      }
      # Suspend after 5 minutes of idle
      {
        timeout = 300;
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
