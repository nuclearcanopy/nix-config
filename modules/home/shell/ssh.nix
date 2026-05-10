{ config, ... }:

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    knownHosts = {
      "github.com" = {
        hostNames = [ "github.com" ];
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
      };
    };

    matchBlocks = {
      "*" = {
        identitiesOnly = true;
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
