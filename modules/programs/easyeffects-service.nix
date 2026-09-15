{
  # User-side easyeffects systemd service: auto-starts on login and
  # applies presets without the GUI being open. Pairs with the easyeffects
  # bucket (which installs the package). Open the GUI to build/save presets,
  # then enable them on the Input pipeline.
  homeManager.modules.easyeffects-service = { lib, ... }: {
    services.easyeffects.enable = true;

    # The stock HM unit hangs off graphical-session.target, which is the wrong
    # target on this host: NixOS also ships nixos-fake-graphical-session.target,
    # which pulls graphical-session.target up at login, well before sway has run
    # `systemctl --user import-environment`. easyeffects then starts with no
    # WAYLAND_DISPLAY and no QT_PLUGIN_PATH, Qt finds no usable platform plugin
    # ("no Qt platform plugin could be initialized"), and it SIGABRTs; the
    # Restart=on-failure below then brings it back 5s later once sway-session is
    # up. Net effect was a coredump on literally every boot (9 in a row by
    # 2026-09-15) plus 5s of unprocessed audio, while the service looked healthy
    # afterwards. Retarget it at sway-session.target, which is what sway starts
    # *after* the env import and what waybar/swayidle/xembedsniproxy already use;
    # mkForce because HM's unit-section lists merge by concatenation, so a plain
    # assignment would append and leave the early graphical-session hook in place.
    # Pipewire ordering stays: without it easyeffects aborts on
    # "No connection to PipeWire" instead.
    systemd.user.services.easyeffects.Unit = {
      After = lib.mkForce [
        "sway-session.target"
        "pipewire.service"
        "pipewire-pulse.service"
        "wireplumber.service"
      ];
      PartOf = lib.mkForce [ "sway-session.target" ];
      Requisite = [ "sway-session.target" ];
    };
    systemd.user.services.easyeffects.Install.WantedBy = lib.mkForce [ "sway-session.target" ];
    # Kept as a backstop for a genuine pipewire restart, not as the startup path.
    systemd.user.services.easyeffects.Service = {
      Restart = lib.mkForce "on-failure";
      RestartSec = 5;
    };
  };
}
