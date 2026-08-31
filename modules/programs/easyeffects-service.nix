{
  # User-side easyeffects systemd service: auto-starts on login and
  # applies presets without the GUI being open. Pairs with the easyeffects
  # bucket (which installs the package). Open the GUI to build/save presets,
  # then enable them on the Input pipeline.
  homeManager.modules.easyeffects-service = { lib, ... }: {
    services.easyeffects.enable = true;

    # The stock HM unit only orders After=graphical-session.target, so at login it
    # can start before pipewire is up (pw_manager.cpp: "No connection to PipeWire.
    # Aborting!") and before WAYLAND_DISPLAY is in the user env, abort (SIGABRT),
    # and dump. Order it behind pipewire and gate it on the graphical session
    # actually being present so a missing display doesn't trigger a retry-abort loop.
    systemd.user.services.easyeffects.Unit = {
      After = [ "pipewire.service" "pipewire-pulse.service" "wireplumber.service" ];
      Requisite = [ "graphical-session.target" ];
    };
    systemd.user.services.easyeffects.Service = {
      Restart = lib.mkForce "on-failure";
      RestartSec = 5;
    };
  };
}
