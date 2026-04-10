{ lib, ... }:

{
  # Laptop-specific Firefox overrides
  programs.firefox.profiles.default.settings = {
    "layout.css.devPixelsPerPx" = lib.mkForce "1.35";

    # Battery savings (laptop only - these limit performance)
    "dom.ipc.processCount" = lib.mkForce 4;  # reduce from default 8
    "media.av1.enabled" = lib.mkForce false;  # AV1 software decode is brutal on CPU
    "layout.frame_rate" = lib.mkForce 60;  # cap at 60fps
    "dom.battery.enabled" = lib.mkForce false;  # don't expose battery to sites
    "beacon.enabled" = lib.mkForce false;  # no background analytics pings
    "dom.push.enabled" = lib.mkForce false;  # no push notifications
    "dom.push.connection.enabled" = lib.mkForce false;
  };
}
