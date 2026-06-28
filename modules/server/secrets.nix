{
  # Homeserver-specific agenix secrets. nas-credentials and ssh-git are
  # declared once in modules/base/secrets.nix and shared via that module;
  # the server imports both to avoid duplicating those declarations.
  nixos.modules.server-secrets = { username, ... }: {
    age.secrets = {
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
}
