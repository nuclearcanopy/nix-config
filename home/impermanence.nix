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
      "Alexandra"
      "heartfetch"
      "avocatsite"

      "MO2"
      "Vortex"

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
      ".config/bolt-launcher"

      ".local/share/Signal"
      ".local/share/bolt-launcher"
    ];

    files = [
      ".gitconfig"
    ];
  };
}
