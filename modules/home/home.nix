{ config, username, ... }:

{
  programs.home-manager.enable = true;

  xdg = {
    enable = true;
    mime.enable = true;
    desktopEntries.bolt-launcher = {
      name = "Bolt Launcher";
      exec = "bolt-launcher";
      icon = "bolt-launcher";
      comment = "RuneScape launcher (Mullvad excluded)";
      categories = [ "Game" ];
    };
  };

  home = {
    username = username;
    homeDirectory = "/home/${username}";
    stateVersion = "25.11";

    sessionVariables = {
      _JAVA_AWT_WM_NONREPARENTING = "1"; # bolt launcher fix
    };
  };

  systemd.user.services.trash-empty = {
    Unit.Description = "Empty trash files older than 3 days";
    Service = {
      Type = "oneshot";
      ExecStart = "${config.home.profileDirectory}/bin/trash-empty 3";
    };
  };
  systemd.user.timers.trash-empty = {
    Unit.Description = "Empty trash every 3 days";
    Timer = {
      OnBootSec = "10min";
      OnUnitActiveSec = "3d";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };

  imports = [
    ./desktop
    ./shell
    ./programs
    ./dev
  ];
}
