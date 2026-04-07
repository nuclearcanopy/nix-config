{ ... }:

{
  programs.git = {
    enable = true;
    settings.user = {
      name = "nuclearcanopy";
      email = "homeserver@nuclearcanopy.git";
    };
  };
}
