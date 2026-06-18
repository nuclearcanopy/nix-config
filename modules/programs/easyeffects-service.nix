{
  # User-side easyeffects systemd service: auto-starts on login and
  # applies presets without the GUI being open. Pairs with the easyeffects
  # bucket (which installs the package). Open the GUI to build/save presets,
  # then enable them on the Input pipeline.
  homeManager.modules.easyeffects-service = {
    services.easyeffects.enable = true;
  };
}
