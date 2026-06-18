{
  # Laptop firefox overrides on top of the generic firefox bucket: VA-API in
  # the sandboxed RDD media process, AV1 software decode off (CPU heavy),
  # battery savers (frame_rate cap, battery API off, push off, beacon off),
  # tab unloading on low memory, fewer content procs for the 4c/8t i5-8350U.
  homeManager.modules.firefox-laptop = { lib, pkgs, ... }: {
    programs.firefox.profiles.default = {
      extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
        auto-tab-discard
      ];

      settings = {
        "media.rdd-ffmpeg.enabled" = lib.mkForce true;

        "media.av1.enabled" = lib.mkForce false;
        "layout.frame_rate" = lib.mkForce 60;
        "dom.battery.enabled" = lib.mkForce false;
        "beacon.enabled" = lib.mkForce false;
        "dom.push.enabled" = lib.mkForce false;
        "dom.push.connection.enabled" = lib.mkForce false;

        "browser.tabs.unloadOnLowMemory" = lib.mkForce true;
        "browser.sessionstore.interval" = lib.mkForce 120000;

        "dom.ipc.processCount" = lib.mkForce 4;
      };
    };
  };
}
