{ config, ... }:

{
  # agenix configuration
  age = {
    identityPaths = [ "/etc/age/key.txt" ];

    secrets = {
      ssh-codeberg = {
        file = ../secrets/ssh-codeberg.age;
        path = "/home/nuclearcanopy/.ssh/id_ed25519_codeberg";
        owner = "nuclearcanopy";
        group = "users";
        mode = "600";
      };

      nas-credentials = {
        file = ../secrets/nas-credentials.age;
        path = "/etc/nas-credentials";
        mode = "600";
      };

      user-password = {
        file = ../secrets/user-password.age;
      };
    };
  };
}
