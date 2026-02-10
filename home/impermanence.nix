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

      # steam persistence moved to system/core/impermanence.nix (NixOS level)
      # to avoid issues with home-manager persistence

      ".local/share/Signal"
    ];

    files = [
      ".gitconfig"
    ];
  };
}
