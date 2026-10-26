{
  homeManager.modules.mako = { config, ... }: {
    services.mako = {
      enable = true;

      settings = {
        default-timeout = 7500;
        padding = "13";
      };

      # background-color/border-color live in an included, swappable file
      # instead of here, so set-theme-mode can flip them without a rebuild.
      extraConfig = "include=${config.xdg.configHome}/mako/colors.ini";
    };

    xdg.configFile."mako/colors-dark.ini".text = ''
      background-color=#000000
      border-color=#141414
    '';
    xdg.configFile."mako/colors-light.ini".text = ''
      background-color=#f0f0f0
      border-color=#a0a0a0
    '';
  };
}
