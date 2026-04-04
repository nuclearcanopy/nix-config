{ config, secrets, ... }:

{
  programs.ssh = {
    enable = true;

    matchBlocks = {
      "codeberg.org" = {
        hostname = "codeberg.org";
        user = "git";
        identityFile = "${config.home.homeDirectory}/.ssh/id_ed25519_codeberg";
      };
    };
  };

  # Create .ssh directory and place keys
  home.file = {
    ".ssh/id_ed25519_codeberg" = {
      text = secrets.ssh.codeberg.privateKey;
      executable = false;
    };
    ".ssh/id_ed25519_codeberg.pub" = {
      text = secrets.ssh.codeberg.publicKey;
      executable = false;
    };
  };

  # Fix permissions on SSH directory
  home.activation.fixSshPermissions = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD chmod 700 ${config.home.homeDirectory}/.ssh
    $DRY_RUN_CMD chmod 600 ${config.home.homeDirectory}/.ssh/id_ed25519_codeberg
    $DRY_RUN_CMD chmod 644 ${config.home.homeDirectory}/.ssh/id_ed25519_codeberg.pub
  '';
}
