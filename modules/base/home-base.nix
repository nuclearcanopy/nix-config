{
  homeManager.modules.home-base = { config, pkgs, username, ... }: {
    programs.home-manager.enable = true;

    home.packages = [
      (pkgs.writeShellScriptBin "bolt-launcher" ''
        exec gamemoderun ${if config.waybar.profile == "kuraokami" then "mullvad-exclude " else ""}${pkgs.bolt-launcher}/bin/bolt-launcher "$@"
      '')
      # Stremio bypasses Mullvad on kuraokami and uses the normal Proton route
      # on nidhoggr; the raw
      # stremio-linux-shell package is dropped from
      # user-packages-common.data.nix so this wrapper owns the `stremio`
      # binary and desktop entry on both hosts.
      # FFMPEG_BIN/FFPROBE_BIN are required: upstream's server.js only ships
      # data/server.js (no bundled ffmpeg-ffprobe-static binary, no /usr/bin
      # fallback on NixOS), so without these it spawns undefined and crashes
      # on stream/playlist probing.
      (pkgs.writeShellScriptBin "stremio" ''
        export FFMPEG_BIN="${pkgs.ffmpeg}/bin/ffmpeg"
        export FFPROBE_BIN="${pkgs.ffmpeg}/bin/ffprobe"
        exec ${if config.waybar.profile == "kuraokami" then "mullvad-exclude " else ""}${pkgs.stremio-linux-shell}/bin/stremio "$@"
      '')
    ];

    xdg = {
      enable = true;
      mime.enable = true;
      desktopEntries.bolt-launcher = {
        name = "Bolt Launcher";
        exec = "bolt-launcher";
        icon = "bolt-launcher";
        comment = if config.waybar.profile == "kuraokami" then "RuneScape launcher (Mullvad excluded)" else "RuneScape launcher";
        categories = [ "Game" ];
      };
      desktopEntries."com.stremio.Stremio" = {
        name = "Stremio";
        exec = "stremio %u";
        icon = "${pkgs.stremio-linux-shell}/share/icons/hicolor/scalable/apps/com.stremio.Stremio.svg";
        comment = if config.waybar.profile == "kuraokami" then "Freedom To Stream (Mullvad excluded)" else "Freedom To Stream";
        categories = [ "AudioVideo" "Video" "Player" ];
        mimeType = [ "x-scheme-handler/stremio" ];
        settings = {
          Keywords = "Stremio;Media;Play;";
          StartupNotify = "true";
        };
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
  };
}
