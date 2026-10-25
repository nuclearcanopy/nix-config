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

        # git send-email auth token (smtp.protonmail.ch); see
        # modules/dev/git-send-email.nix.
        smtp-protonmail = {
          file = ../../secrets/smtp-protonmail.age;
          path = "/run/agenix/smtp-protonmail";
          owner = username;
          group = "users";
          mode = "600";
        };

        # bare email (line 1) + "Display Name <email>" (line 2); see
        # modules/dev/git-send-email.nix. Kept out of the repo deliberately:
        # this file is public.
        git-send-email-identity = {
          file = ../../secrets/git-send-email-identity.age;
          path = "/run/agenix/git-send-email-identity";
          owner = username;
          group = "users";
          mode = "600";
        };

        # [user] name/email for kernel.org git commits only; see
        # modules/dev/git.nix's includeIf. Kept out of the repo deliberately:
        # this identity must never be linked to this GitHub account.
        kernel-git-identity = {
          file = ../../secrets/kernel-git-identity.age;
          path = "/run/agenix/kernel-git-identity";
          owner = username;
          group = "users";
          mode = "600";
        };
      };
    };
  };
}
