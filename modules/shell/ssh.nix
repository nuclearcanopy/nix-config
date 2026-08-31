{
  homeManager.modules.ssh = {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;

      settings = {
        "*" = {
          IdentitiesOnly = "yes";
        };
        "homeserver 192.168.0.110" = {
          hostname = "192.168.0.110";
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
          IdentityFile = "/run/agenix/ssh-github";
        };
      };
    };

    home.file.".ssh/id_ed25519_codeberg.pub".text =
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEw3uZ/5xY3VHdAJEcY9rGntIbXOUwA5yFWDx/wPGeNr";

    home.file.".ssh/id_ed25519_github.pub".text =
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOO8X+CMomzKbSuKWeQW6mMROZbeq/E1exh4T4JtmMwv";
  };
}
