{ pkgs, ... }:

{
  programs.vesktop = {
    enable = true;

    package = pkgs.vesktop;

    settings = {
      discordBranch = "stable";

      hardwareAcceleration = true;
      hardwareVideoAcceleration = true;

      staticTitleBar = true;
      minimizeToTray = true;
      arRPC = false;

      splashColor = "rgb(204, 204, 204)";
      splashBackground = "rgb(12, 12, 12)";
    };
  };

  home.file.".config/vesktop/settings/settings.json".text = builtins.toJSON {
    notifyAboutUpdates = false;
    autoUpdate = false;
    disableMinSize = true;
    enabledThemes = [];
    plugins = {
      AnonymiseFileNames.enabled = true;
      ClearURLs.enabled = true;
      CallTimer.enabled = true;
      FakeNitro = {
        enabled = true;
        enableEmojiBypass = false;
        transformEmojis = false;
        enableStickerBypass = false;
        transformStickers = false;
        enableStreamQualityBypass = true;
      };
      ClientTheme = {
        enabled = true;
        color = "0c0c0c";
      };
    };
  };
}
