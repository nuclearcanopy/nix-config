{ config, username, secrets, ... }:

{
  programs.home-manager.enable = true;

  # xdg
  xdg = {
    enable = true;
    mime.enable = true;
  };

  # home
  home = {
    username = username;
    homeDirectory = "/home/${username}";
    stateVersion = "25.11";

    sessionVariables = {
      _JAVA_AWT_WM_NONREPARENTING = "1"; # bolt launcher fix
    };
  };

  # trash cleanup timer
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

  # font config
  fonts.fontconfig = {
    enable = true;
    defaultFonts = {
      monospace = [ "JetBrainsMono Nerd Font" ];
      sansSerif = [ "Noto Sans" ];
      emoji = [ "Noto Color Emoji" ];
    };
  };

  imports = [
    # desktop
    ./desktop/packages.nix
    ./desktop/sway.nix
    ./desktop/waybar/config.nix
    ./desktop/mako.nix
    ./desktop/theme.nix

    # shell
    ./shell/zsh/zsh.nix
    ./shell/packages.nix
    ./shell/environment.nix
    ./shell/alacritty.nix
    ./shell/ssh.nix

    # programs
    ./programs/packages.nix
    ./programs/neovim/config.nix
    ./programs/btop.nix
    ./programs/vesktop.nix
    ./programs/steam.nix
    ./programs/asunder.nix
    ./programs/easyeffects.nix
    ./programs/vkbasalt.nix
    ./programs/firefox.nix

    # development
    ./dev/packages.nix
    ./dev/claudecode.nix
  ];
}
