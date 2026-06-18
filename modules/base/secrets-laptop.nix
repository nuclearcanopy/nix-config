{
  # Laptop variant of the secrets bucket. Same secret files as the generic
  # secrets bucket, but nas-credentials uses owner+group+mode 640 (the user
  # also reads it) rather than the kuraokami flavor's root-only 600.
  # Assumes the SAME age key as kuraokami at /etc/age/key.txt. For a separate
  # nidhoggr key:
  #   age-keygen -o /etc/age/key.txt (on nidhoggr)
  #   add pubkey to secrets/secrets.nix under `nidhoggr`
  #   cd secrets && agenix -e <file> for every referenced secret
  nixos.modules.secrets-laptop = { username, ... }: {
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

        user-password = {
          file = ../../secrets/user-password.age;
        };

        nas-credentials = {
          file = ../../secrets/nas-credentials.age;
          owner = username;
          group = "users";
          mode = "640";
        };
      };
    };
  };
}
