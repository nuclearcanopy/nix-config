{ ... }:

{
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    xwayland.enable = true;
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    WLR_DRM_NO_ATOMIC = "1";  # fix DP atomic modesetting crashes
  };

}
