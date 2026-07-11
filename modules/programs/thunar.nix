{
  # Thunar (XFCE file manager) with the usual companions:
  # - xfconf: persistent settings
  # - gvfs: trash, network mounts, mtp
  # - tumbler: thumbnails
  # - archive + volman plugins: archive ops and auto-mount
  nixos.modules.thunar = { pkgs, ... }: {
    programs.thunar = {
      enable = true;
      plugins = with pkgs.xfce; [
        thunar-archive-plugin
        thunar-volman
      ];
    };

    programs.xfconf.enable = true;
    services.gvfs.enable = true;
    services.tumbler.enable = true;
  };
}
