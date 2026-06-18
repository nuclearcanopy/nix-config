{
  # Homeserver user, ssh authorized keys (kuraokami pubkey), zsh shell,
  # codeberg known_hosts + ssh config for git push.
  nixos.modules.server-users = { config, pkgs, username, ... }: {
    programs.git = {
      enable = true;
      config = {
        user.name = username;
        user.email = "nuclearcanopy@local";
      };
    };

    users.users.${username} = {
      isNormalUser = true;
      description = username;
      extraGroups = [ "networkmanager" "wheel" "docker" ];

      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEw3uZ/5xY3VHdAJEcY9rGntIbXOUwA5yFWDx/wPGeNr nuclearcanopy"
      ];

      hashedPasswordFile = config.age.secrets.homeserver-user-password.path;

      shell = pkgs.zsh;
      packages = [];
    };

    users.defaultUserShell = pkgs.zsh;

    programs.ssh.knownHosts = {
      "codeberg.org".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIVIC02vnjFyL+I4RHfvIGNtOgJMe769VTF1VR4EB3ZB";
    };

    programs.ssh.extraConfig = ''
      Host codeberg.org
        User git
        IdentityFile /home/${username}/.ssh/id_git
        IdentitiesOnly yes
    '';
  };
}
