{
  homeManager.modules.git = { username, ... }: {
    programs.git = {
      enable = true;
      settings.user = {
        name = username;
        email = "${username}@local";
      };
    };
  };
}
