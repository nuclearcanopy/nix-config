{
  # ThinkPad firmware updates via LVFS.
  nixos.modules.fwupd = {
    services.fwupd.enable = true;
  };
}
