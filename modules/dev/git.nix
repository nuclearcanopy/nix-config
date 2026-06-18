{
  homeManager.modules.git = {
    programs.git = {
      enable = true;
      settings.user = {
        name = "nuclearcanopy";
        email = "nuclearcanopy@local";
      };
    };
  };
}
