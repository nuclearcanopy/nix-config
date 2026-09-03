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
        # Homeserver login key (laptop/desktop -> homeserver); the matching
        # pubkey is in server-users authorizedKeys.
        ssh-git = {
          file = ../../secrets/ssh-git.age;
          path = "/run/agenix/ssh-git";
          owner = username;
          group = "users";
          mode = "600";
        };

        # Git forge key; the only remote is github.com/nuclearcanopy.
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

        # Home wifi SSID, kept out of the repo to avoid an OSINT leak. Used
        # by swayidle to skip idle-suspend when connected to the home network.
        home-wifi-ssid = {
          file = ../../secrets/home-wifi-ssid.age;
          path = "/run/agenix/home-wifi-ssid";
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
