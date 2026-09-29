{
  # Official Discord client, replacing Vesktop (2026-09-16).
  #
  # Unfree, so "discord" is in modules/nix/allowed-unfree.data.nix; lib.getName
  # resolves this package's pname to exactly "discord", which is what the
  # allowUnfreePredicate in modules/nix/allow-unfree.nix matches on.
  #
  # Runs natively on Wayland rather than XWayland because NIXOS_OZONE_WL=1 is
  # set session-wide in modules/gui/sway-system.nix and the nixpkgs Electron
  # wrapper keys its ozone flags off that.
  #
  # There is no home-manager module for discord (unlike programs.vesktop), so
  # settings are not declarative: everything lives in ~/.config/discord and is
  # written by the app itself.
  homeManager.modules.discord = { pkgs, ... }: {
    home.packages = [ pkgs.discord ];
  };
}
