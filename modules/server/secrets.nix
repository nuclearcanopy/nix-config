{
  # Homeserver-specific agenix secrets, including the shared GitHub and NAS keys.
  nixos.modules.server-secrets = { username, ... }: {
    age = {
      identityPaths = [ "/etc/age/key.txt" ];

      secrets = {
        # Shared services: the NAS mount and GitHub pull access.
        ssh-github = {
          file = ../../secrets/ssh-github.age;
          path = "/run/agenix/ssh-github";
          owner = username;
          group = "users";
          mode = "600";
        };

        nas-credentials = {
          file = ../../secrets/nas-credentials.age;
          owner = username;
          group = "users";
          mode = "640";
        };

        homeserver-user-password = {
          file = ../../secrets/homeserver-user-password.age;
        };

        homeserver-navidrome-env = {
          file = ../../secrets/homeserver-navidrome-env.age;
          path = "/run/agenix/homeserver-navidrome-env";
          mode = "600";
        };

        homeserver-cloudflared-credentials = {
          file = ../../secrets/homeserver-cloudflared-credentials.age;
          mode = "644";
        };

        homeserver-cloudflared-config = {
          file = ../../secrets/homeserver-cloudflared-config.age;
          mode = "644";
        };

        homeserver-mscd-api-hash = {
          file = ../../secrets/homeserver-mscd-api-hash.age;
          path = "/run/agenix/homeserver-mscd-api-hash";
          mode = "600";
        };
      };
    };
  };
}
