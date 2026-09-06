{
  # Minimal GUI file manager for nidhoggr, replacing the Thunar stack.
  #
  # Thunar dragged in tumbler (D-Bus thumbnailer), xfconf (XFCE settings
  # daemon) and thunar-volman purely to function; ~2.4GB for a file manager
  # opened occasionally. pcmanfm is ~310MB and does its own thumbnailing via
  # libfm, so tumbler and xfconf are both gone.
  #
  # gvfs stays: GTK file managers get removable-media mounting through it, so
  # dropping it would cost USB auto-mount and the GUI trash backend. That is
  # the one piece of the old stack pcmanfm still needs. Enable automount in
  # pcmanfm under Edit > Preferences > Volume Management (it is off by
  # default); the setting lands in ~/.config/pcmanfm/default/pcmanfm.conf and
  # is not managed here.
  nixos.modules.pcmanfm = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.pcmanfm ];

    services.gvfs.enable = true;
  };
}
