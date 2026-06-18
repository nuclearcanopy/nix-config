{
  # Agenix wiring + per-secret declarations. Identity at /etc/age/key.txt is
  # provided by the user out-of-band; encrypted .age blobs live in secrets/.
  # nas-credentials is user-readable (group=users, mode=640) so user-space
  # tools can resolve the mount without root; the cifs mount itself still
  # runs as root and uses the file path.
  nixos.modules.secrets = { username, ... }: {
    age = {
      identityPaths = [ "/etc/age/key.txt" ];

      secrets = {
        ssh-git = {
          file = ../../secrets/ssh-codeberg.age;
          path = "/run/agenix/ssh-git";
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

        user-password = {
          file = ../../secrets/user-password.age;
        };
      };
    };
  };
}
