{ config, ... }:

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    matchBlocks = {
      "*" = {
        identitiesOnly = true;
      };
      "homeserver" = {
        hostname = "homeserver";
        user = "homeserver";
        port = 1208;
        identityFile = "/run/agenix/ssh-git";
      };
      "codeberg.org" = {
        hostname = "codeberg.org";
        user = "git";
        identityFile = "/run/agenix/ssh-git";
      };
      "github.com" = {
        hostname = "github.com";
        user = "git";
        identityFile = "/run/agenix/ssh-git";
      };
    };
  };

  home.file.".ssh/id_ed25519_codeberg.pub".text =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEw3uZ/5xY3VHdAJEcY9rGntIbXOUwA5yFWDx/wPGeNr";
}
