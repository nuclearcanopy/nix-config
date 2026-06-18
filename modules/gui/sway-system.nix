{
  # System-side sway enablement. The user-side sway config lives in the
  # sway-base bucket (homeManager).
  nixos.modules.sway-system = {
    programs.sway = {
      enable = true;
      wrapperFeatures.gtk = true;
      xwayland.enable = true;
    };

    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
    };
  };
}
