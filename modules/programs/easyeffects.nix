{
  # Just installs easyeffects. No declarative presets; user configures
  # in-app per host (different audio interfaces per machine).
  homeManager.modules.easyeffects = { pkgs, ... }: {
    home.packages = [ pkgs.easyeffects ];
  };
}
