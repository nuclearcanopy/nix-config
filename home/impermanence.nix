{ config, lib, username, ... }:

{
  home.persistence."/persist/home/${username}" = {
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

      ".local/share/Steam"
      ".local/share/nvim"
      ".local/state/nvim"
    ];

    files = [
      ".gitconfig"
    ];

    allowOther = true;
  };
}
