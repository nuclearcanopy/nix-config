{ config, ... }:

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    matchBlocks = {
      "*" = {
        identitiesOnly = true;
      };
      "codeberg.org" = {
        hostname = "codeberg.org";
        user = "git";
        identityFile = "${config.home.homeDirectory}/.ssh/id_ed25519_codeberg";
      };
    };
  };

  # Public key can be managed by home-manager (not sensitive)
  home.file.".ssh/id_ed25519_codeberg.pub".text =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEw3uZ/5xY3VHdAJEcY9rGntIbXOUwA5yFWDx/wPGeNr";
}
