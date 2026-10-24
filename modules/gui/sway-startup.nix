{
  # Common sway startup commands run on session-init for every host.
  # autotiling-rs keeps containers tiled in the most ergonomic split.
  # easyeffects is NOT launched here; on nidhoggr (the only host that
  # autostarts it) the systemd user service in easyeffects-service.nix
  # starts it on sway-session.target, after sway's env import has run.
  # Launching from sway startup raced the Qt platform-plugin init and
  # produced "no Qt platform plugin could be initialized" errors.
  homeManager.modules.sway-startup = {
    wayland.windowManager.sway.config.startup = [
      { command = "autotiling-rs"; }
    ];
  };
}
