{
  # Git author identity comes from this module, not the system username
  # (loaded from secrets/identity.age at install time).
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
