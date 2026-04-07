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

    # Password for SSH (temporary - will be managed by agenix later)
    # Password: winterwyrm
    # Generated with: mkpasswd -m sha-512
    hashedPassword = "$6$rounds=656000$YCKvE3qKJfQ3rLmG$Kq7vL5M3XhQ3Z8FdmT5N1P9xJ7R4W2L6E8K0M5Q9V7S3Y1H6N2B8C4D0F9G5J3K7M1P4R6T8V2W9X5Z1A3C5E7G";

    shell = pkgs.zsh;
    packages = with pkgs; [];
  };

  users.defaultUserShell = pkgs.zsh;
}
