{
  nixos.modules.displaymanager-ly = {
    services.displayManager = {
      ly = {
        enable = true;
        settings = {
          animate = false;
        };
      };
      defaultSession = "sway";
    };
  };
}
