{ config, pkgs, lib, ... }:

let
  mscdScript = pkgs.writeTextFile {
    name = "mscd.zsh";
    text = builtins.readFile ../../scripts/mscd.zsh;
  };
in
{
  programs.zsh = {
    enable = true;
    interactiveShellInit = ''
      source ${mscdScript}

      # Auto-start btop on TTY1 (outermost shell only, not nested or SSH)
      if [[ $SHLVL -eq 1 && $(tty) == /dev/tty1 ]]; then
        btop
      fi

      elevate() {
        if command -v doas >/dev/null 2>&1; then
          doas "$@"; return $?
        fi
        sudo -H "$@"
      }

      export NIX_FLAKE_DIR="$HOME/nix-config"
      export NIX_FLAKE_HOST="homeserver"
      source ~/nix-config/scripts/nix-commit.zsh

      sync() {
        sudo mkdir -p /mnt/nas/homeserver/etc
        sudo mkdir -p /mnt/nas/homeserver/var/lib

        sudo rsync -av --delete ~/nix-config /mnt/nas/homeserver/etc/
        sudo rsync -av --delete --exclude='cache' /var/lib/navidrome /mnt/nas/homeserver/var/lib/
        sudo rsync -av --delete /var/lib/filebrowser /mnt/nas/homeserver/var/lib/
        sudo rsync -av --delete /var/lib/portainer /mnt/nas/homeserver/var/lib/
        sudo rsync -av --delete /var/lib/vaultwarden /mnt/nas/homeserver/var/lib/
      }
    '';
  };
}
