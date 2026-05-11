{ lib, pkgs, ... }:

{
  # PSD leaves a stale symlink at ~/.mozilla/firefox/<profile> pointing to
  # /run/user/1000/psd/... (tmpfs) on crash/unclean shutdown. HM's linkGeneration
  # can't mkdir through a broken symlink, so restore from PSD's backup first.
  home.activation.fixPsdFirefoxLinks = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
    for profile in default compat; do
      link="$HOME/.mozilla/firefox/$profile"
      backup="$HOME/.mozilla/firefox/${profile}-backup"
      if [ -L "$link" ] && [ ! -e "$link" ]; then
        $DRY_RUN_CMD rm "$link"
        if [ -d "$backup" ]; then
          $DRY_RUN_CMD cp -a "$backup" "$link"
        else
          $DRY_RUN_CMD mkdir "$link"
        fi
      fi
    done
  '';

  # Laptop-specific Firefox overrides
  programs.firefox.profiles.default = {
    extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
      auto-tab-discard
    ];

    settings = {
      "layout.css.devPixelsPerPx" = lib.mkForce "1.35";

      # VA-API in the sandboxed RDD media process (without this, VA-API is unused despite being "enabled")
      "media.rdd-ffmpeg.enabled" = lib.mkForce true;

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
