{
  # Homeserver user, ssh authorized keys (desktop pubkey for remote shell), zsh
  # shell, github known_hosts + ssh config for git push.
  nixos.modules.server-users = { config, pkgs, username, ... }: {
    programs.git = {
      enable = true;
      config = {
        user.name = username;
        user.email = "${username}@local";
      };
    };

    users.users.${username} = {
      isNormalUser = true;
      description = username;
      extraGroups = [ "networkmanager" "wheel" "docker" ];

      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEw3uZ/5xY3VHdAJEcY9rGntIbXOUwA5yFWDx/wPGeNr"
      ];

      hashedPasswordFile = config.age.secrets.homeserver-user-password.path;

      shell = pkgs.zsh;
      packages = [];
    };

    users.defaultUserShell = pkgs.zsh;

    programs.ssh.knownHosts = {
      "github.com".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
    };

    programs.ssh.extraConfig = ''
      Host github.com
        User git
        IdentityFile /home/${username}/.ssh/id_github
        IdentitiesOnly yes
    '';
  };
}
