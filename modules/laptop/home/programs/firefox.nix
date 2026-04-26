{ lib, pkgs, ... }:

{
  # Laptop-specific Firefox overrides
  programs.firefox.profiles.default = {
    extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
      auto-tab-discard
    ];

    settings = {
      "layout.css.devPixelsPerPx" = lib.mkForce "1.35";

      # Battery savings
      "media.av1.enabled" = lib.mkForce false;          # AV1 software decode is brutal on CPU
      "layout.frame_rate" = lib.mkForce 60;              # cap at 60fps
      "dom.battery.enabled" = lib.mkForce false;         # don't expose battery to sites
      "beacon.enabled" = lib.mkForce false;              # no background analytics pings
      "dom.push.enabled" = lib.mkForce false;            # no push notifications
      "dom.push.connection.enabled" = lib.mkForce false;

      # Tab unloading for memory/battery
      "browser.tabs.unloadOnLowMemory" = lib.mkForce true;
      "browser.sessionstore.interval" = lib.mkForce 120000;  # 2min sessionstore writes
    };
  };
}
