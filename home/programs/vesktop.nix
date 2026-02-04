{ ... }:

{
  
  # --/ DISCORD SETTINGS /---
  programs.vesktop = {
    enable = true;

    settings = {
      discordBranch = "stable";

      hardwareAcceleration = true;
      hardwareVideoAcceleration = true;

      staticTitleBar = true;
      minimizeToTray = true;
      arRPC = false;

      splashColor = "rgb(204, 204, 204)";
      splashBackground = "rgb(0, 0, 0)";
    };
  };

  # plugins
  home.file.".config/vesktop/settings/settings.json".text = builtins.toJSON {
    # privacy
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
        color = "121212";
      };
    };
  };
}
