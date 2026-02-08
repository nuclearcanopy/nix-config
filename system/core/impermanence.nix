{ config, lib, ... }:

{
  # Ensure /persist exists early and is available
  #fileSystems."/persist" = {
  #  device = config.fileSystems."/".device;
  #  fsType = config.fileSystems."/".fsType;
  # neededForBoot = true;
  #  options = [ "bind" ];
  #};

  # Impermanence persistence rules
  environment.persistence."/persist" = {
    hideMounts = true;

    directories = [
      "/var/lib/nixos"
      "/var/lib/systemd"
      "/var/log"
      "/etc/ssh"
      # add NetworkManager / bluetooth etc if you use them
      "/var/lib/NetworkManager"
      "/var/lib/bluetooth"
    ];

    files = [
      "/etc/machine-id"
    ];

    # per-user state (replace username)
    users.nuclearcanopy = {
      directories = [
        "nix-config"

        "Downloads"
        "Documents"
        "Pictures"
        "Videos"

        ".ssh"
        ".gnupg"
        ".local/share/keyrings"

        ".mozilla"
	      ".librewolf"
      
        ".config/Proton"
        ".config/vesktop"

        ".local/share/Steam"
      ];

      files = [
        ".gitconfig"
      ];
    };
  };

  # Recommended: keep /tmp ephemeral
  boot.tmp.useTmpfs = true;
}
