{ config, pkgs, lib, ... }:

{
  users.users.homeserver = {
    isNormalUser = true;
    description = "homeserver";
    extraGroups = [ "networkmanager" "wheel" "docker" ];

    # SSH public key authentication
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII36Xlq4Kisgp2YlSezcA3p5LSobE2PBnjiW3zCW+z9v nuclearcanopy@codeberg.org"
    ];

    # Managed by agenix
    hashedPasswordFile = config.age.secrets.homeserver-user-password.path;

    shell = pkgs.zsh;
    packages = with pkgs; [];
  };

  users.defaultUserShell = pkgs.zsh;

  # SSH client config for Codeberg
  programs.ssh.extraConfig = ''
    Host codeberg.org
      User git
      IdentityFile /home/homeserver/.ssh/id_codeberg
      IdentitiesOnly yes
  '';
}
