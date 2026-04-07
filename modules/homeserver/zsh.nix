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
      # Load MSCD script
      source ${mscdScript}

      # Auto-connect Mullvad VPN
      mullvad connect

      elevate() {
        if command -v doas >/dev/null 2>&1; then
          doas "$@"; return $?
        fi
        sudo -H "$@"
      }

      nix-commit() {
        echo " Changes"
        git -C ~/nix-config/ diff --stat --color=always
        git -C ~/nix-config/ add .

        echo "󱄅 Rebuilding..."
        if elevate nixos-rebuild switch --flake ~/nix-config/#homeserver --show-trace --option warn-dirty false 2>&1 | tee /tmp/nix-build-log; then
          BUILD_SUCCESS=true
        else
          BUILD_SUCCESS=false
        fi

        if [ "$BUILD_SUCCESS" = true ]; then
          GEN=$(nixos-rebuild list-generations --flake ~/nix-config/#homeserver | grep True | awk '{print $1 " (" $2 " " $3 ")"}')
          GEN_NUM=$(nixos-rebuild list-generations --flake ~/nix-config/#homeserver | grep True | awk '{print $1}')
          git -C ~/nix-config/ commit -m "Rebuild: $GEN" --quiet
          echo "󰊢 Syncing..."
          git -C ~/nix-config/ push origin main --quiet > /dev/null 2>&1
          echo " Done. (Gen $GEN_NUM)"
        else
          echo "󰚌 Build Failed"
          git -C ~/nix-config/ reset --quiet
        fi
      }

      nix-upd() {
        echo " Changes"
        git -C ~/nix-config/ diff --stat --color=always
        git -C ~/nix-config/ add .

        echo "󱄅 Rebuilding..."
        if elevate nixos-rebuild switch --flake ~/nix-config/#homeserver --show-trace --option warn-dirty false 2>&1 | tee /tmp/nix-build-log; then
          BUILD_SUCCESS=true
        else
          BUILD_SUCCESS=false
        fi

        git -C ~/nix-config/ reset --quiet

        if [ "$BUILD_SUCCESS" = true ]; then
          GEN_NUM=$(nixos-rebuild list-generations --flake ~/nix-config/#homeserver | grep True | awk '{print $1}')
          echo " Done. (Gen $GEN_NUM)"
        else
          echo "󰚌 Build Failed"
        fi
      }

      nix-clone() {
        echo "󰊢 Pulling latest from Codeberg..."
        git -C ~/nix-config/ pull origin main || { echo "󰚌 Pull failed"; return 1; }

        echo "󱄅 Rebuilding..."
        if elevate nixos-rebuild switch --flake ~/nix-config/#homeserver --show-trace --option warn-dirty false 2>&1 | tee /tmp/nix-build-log; then
          GEN_NUM=$(nixos-rebuild list-generations --flake ~/nix-config/#homeserver | grep True | awk '{print $1}')
          echo " Done. (Gen $GEN_NUM)"
        else
          echo "󰚌 Build Failed"
        fi
      }

      # Sync function for backing up to NAS
      sync() {
        sudo mkdir -p /mnt/nas/homeserver/etc
        sudo mkdir -p /mnt/nas/homeserver/var/lib

        sudo rsync -av --delete ~/nix-config /mnt/nas/homeserver/etc/
        sudo rsync -av --delete --exclude='cache' /var/lib/navidrome /mnt/nas/homeserver/var/lib/
        sudo rsync -av --delete /var/lib/searxng /mnt/nas/homeserver/var/lib/
        sudo rsync -av --delete /var/lib/cloudflared /mnt/nas/homeserver/var/lib/
        sudo rsync -av --delete /var/lib/filebrowser /mnt/nas/homeserver/var/lib/
        sudo rsync -av --delete /var/lib/portainer /mnt/nas/homeserver/var/lib/
        sudo rsync -av --delete /var/lib/vaultwarden /mnt/nas/homeserver/var/lib/
      }
    '';
  };
}
