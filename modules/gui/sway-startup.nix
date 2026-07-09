{
  # Common sway startup commands run on session-init for every host.
  # autotiling-rs keeps containers tiled in the most ergonomic split.
  # easyeffects is NOT launched here; the systemd user service
  # (easyeffects-service.nix, services.easyeffects.enable) starts it
  # after graphical-session.target when Qt/wayland env is fully set up.
  # Launching from sway startup raced the Qt platform-plugin init and
  # produced "no Qt platform plugin could be initialized" errors.
  homeManager.modules.sway-startup = {
    wayland.windowManager.sway.config.startup = [
      { command = "autotiling-rs"; }
    ];
  };
}
