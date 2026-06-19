{
  # Git author identity is decoupled from the system username. The live
  # system runs as system username (via secrets/identity.age) for backwards
  # compatibility with existing UIDs/paths, but every commit signs as
  # the public nuclearcanopy identity instead.
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
