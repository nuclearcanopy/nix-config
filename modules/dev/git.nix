{
  # Git author identity is set here, separately from the system username.
  homeManager.modules.git = {
    programs.git = {
      enable = true;
      settings.user = {
        name = "nuclearcanopy";
        email = "git_l7a153rj3z@proton.me";
      };
    };
  };
}
