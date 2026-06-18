{
  # Home-side steam tweaks (download throttling, shader background threads).
  # Pairs with the system-side gaming bucket which installs programs.steam.
  homeManager.modules.steam-home = {
    home.file.".steam/steam/steam_dev.cfg".text = ''
      @nClientDownloadEnableHTTP2PlatformLinux 0
      @fDownloadRateImprovementToAddAnotherConnection 1.0
      unShaderBackgroundProcessingThreads 4
    '';
  };
}
