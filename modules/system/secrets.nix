{ config, username, ... }:

{
  age = {
    identityPaths = [ "/etc/age/key.txt" ];

    secrets = {
      ssh-codeberg = {
        file = ../../secrets/ssh-codeberg.age;
        path = "/run/agenix/ssh-codeberg";
        owner = username;
        group = "users";
        mode = "600";
      };

      nas-credentials = {
        file = ../../secrets/nas-credentials.age;
        path = "/run/agenix/nas-credentials";
        mode = "600";
      };

      user-password = {
        file = ../../secrets/user-password.age;
      };
    };
  };
}
