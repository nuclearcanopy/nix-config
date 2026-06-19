{
  # Common sway startup commands run on session-init for every host.
  # easyeffects runs windowless so audio presets apply without the GUI;
  # autotiling-rs keeps containers tiled in the most ergonomic split.
  homeManager.modules.sway-startup = {
    wayland.windowManager.sway.config.startup = [
      { command = "easyeffects -w"; }
      { command = "autotiling-rs"; }
    ];
  };
}
