{ config, ... }:

{
  age = {
    identityPaths = [ "/etc/age/key.txt" ];

    secrets = {
      nas-credentials = {
        file = ../../secrets/nas-credentials.age;
        path = "/run/agenix/nas-credentials";
        mode = "600";
      };

      ssh-codeberg = {
        file = ../../secrets/ssh-codeberg.age;
        path = "/home/homeserver/.ssh/id_codeberg";
        mode = "600";
        owner = "homeserver";
      };

      homeserver-user-password = {
        file = ../../secrets/homeserver-user-password.age;
      };

      homeserver-navidrome-env = {
        file = ../../secrets/homeserver-navidrome-env.age;
        path = "/run/agenix/homeserver-navidrome-env";
        mode = "600";
      };

      homeserver-searxng-env = {
        file = ../../secrets/homeserver-searxng-env.age;
        path = "/run/agenix/homeserver-searxng-env";
        mode = "600";
      };

      homeserver-cloudflared-credentials = {
        file = ../../secrets/homeserver-cloudflared-credentials.age;
        mode = "644";
      };

      homeserver-mscd-api-hash = {
        file = ../../secrets/homeserver-mscd-api-hash.age;
        path = "/run/agenix/homeserver-mscd-api-hash";
        mode = "600";
      };
    };
  };
}
