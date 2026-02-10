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

      # steam - use symlink method to avoid breakage
      ".steam"
      {
        directory = ".local/share/Steam";
        method = "symlink";
      }
      ".cache/mesa_shader_cache"  # mesa shader cache for native games

      ".local/share/Signal"
    ];

    files = [
      ".gitconfig"
    ];
  };
}
