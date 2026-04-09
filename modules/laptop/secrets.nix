{ config, username, ... }:

# Secrets for nidhoggr.
#
# This assumes the SAME age key as kuraokami (/etc/age/key.txt).
# If you want a separate key for nidhoggr:
#   1. Generate: age-keygen -o /etc/age/key.txt  (on nidhoggr)
#   2. Add the public key to secrets/secrets.nix under `nidhoggr`
#   3. Re-encrypt all referenced secrets: cd secrets && agenix -e <file>
#   4. Create nidhoggr-user-password.age for a separate password
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

      # Reuses kuraokami's user-password secret (same age key, same password hash).
      # See note above if you want a separate password.
      user-password = {
        file = ../../secrets/user-password.age;
      };
    };
  };
}
