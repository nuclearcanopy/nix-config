{ config, lib, username, ... }:

{
  home.persistence."/persist" = {
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
      ".claude"

      ".config/Proton"
      ".config/vesktop"
      ".config/FreeTube"
      ".config/Signal"

      ".steam"
      ".local/share/Steam"
      ".local/share/Signal"
    ];

    files = [
      ".gitconfig"
    ];
  };
}
