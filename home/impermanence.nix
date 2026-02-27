{ config, lib, username, ... }:

{
  home.persistence."/persist" = {
    directories = [
      "nix-config"

      "Downloads"
      "Documents"
      "Pictures"
      "Videos"
      "Games" 
      "avocatsite"

      ".ssh"
      ".gnupg"
      ".local/share/keyrings"

      ".mozilla"
      ".librewolf"
      ".claude"

      ".config/vesktop"
      ".config/FreeTube"
      ".config/Signal"
      ".config/Feishin"

      ".local/share/Signal"
      ".local/bin"
    ];

    files = [
      ".gitconfig"
    ];
  };
}
