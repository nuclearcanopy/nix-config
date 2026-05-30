{ config, ... }:

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings = {
      "*" = {
        IdentitiesOnly = "yes";
      };
      "homeserver" = {
        hostname = "homeserver";
        user = "homeserver";
        port = 1208;
        identityFile = "/run/agenix/ssh-git";
      };
      "codeberg.org" = {
        Hostname = "codeberg.org";
        User = "git";
        IdentityFile = "/run/agenix/ssh-git";
      };
      "github.com" = {
        Hostname = "github.com";
        User = "git";
        IdentityFile = "/run/agenix/ssh-git";
      };
    };
  };

  home.file.".ssh/id_ed25519_codeberg.pub".text =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEw3uZ/5xY3VHdAJEcY9rGntIbXOUwA5yFWDx/wPGeNr";
}
