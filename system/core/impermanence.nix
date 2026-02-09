{ config, lib, username, ... }:

{
  environment.persistence."/persist" = {
    hideMounts = true;

    directories = [
      "/var/lib/nixos"
      "/var/lib/systemd"
      "/var/log"
      "/etc/ssh"
      "/var/lib/NetworkManager"
    ];

    files = [
      "/etc/machine-id"
    ];

    users.${username} = {
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
        ".config/FreeTube"

        ".local/share/Steam"
	      ".local/share/nvim"
	      ".local/state/nvim"
	      # ".cache/nvim"
      ];

      files = [
        ".gitconfig"
      ];
    };
  };

  boot.tmp.useTmpfs = true;
}
