{ config, username, ... }:

{
  programs.home-manager.enable = true;

  xdg = {
    enable = true;
    mime.enable = true;

    # libinput-gestures config for touchscreen/touchpad
    configFile."libinput-gestures.conf".text = ''
      # 3-finger swipe to switch workspaces
      gesture swipe left  3 swaymsg workspace next
      gesture swipe right 3 swaymsg workspace prev

      # 4-finger swipe for window focus
      gesture swipe left  4 swaymsg focus right
      gesture swipe right 4 swaymsg focus left
      gesture swipe up    4 swaymsg focus up
      gesture swipe down  4 swaymsg focus down

      # 3-finger pinch to toggle fullscreen
      gesture pinch in  3 swaymsg fullscreen toggle
      gesture pinch out 3 swaymsg fullscreen toggle
    '';
  };

  home = {
    username = username;
    homeDirectory = "/home/${username}";
    stateVersion = "25.11";

    activation.setNixConfigRemote = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      if [ -d "$HOME/nix-config/.git" ]; then
        ${config.home.profileDirectory}/bin/git -C "$HOME/nix-config" remote set-url origin git@codeberg.org:nuclearcanopy/nix-config.git 2>/dev/null || true
      fi
    '';
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
    # Shell: reuse kuraokami config entirely
    ../home/shell
    # Programs: pick what makes sense on a laptop, skip gaming/studio
    ../home/programs/firefox.nix
    ./programs/firefox.nix  # laptop-specific overrides (devPixelsPerPx)
    ../home/programs/neovim/config.nix
    ../home/programs/btop.nix
    ../home/programs/vesktop.nix
    ./programs/packages.nix
    # Dev: reuse kuraokami config entirely
    ../home/dev
  ];
}
