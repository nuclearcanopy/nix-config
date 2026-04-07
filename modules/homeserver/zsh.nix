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

      # Sync function for backing up to NAS
      sync() {
        sudo mkdir -p /mnt/nas/homeserver/etc
        sudo mkdir -p /mnt/nas/homeserver/var/lib

        sudo rsync -av --delete /home/homeserver/nix-config /mnt/nas/homeserver/etc/
        sudo rsync -av --delete --exclude='cache' /var/lib/navidrome /mnt/nas/homeserver/var/lib/
        sudo rsync -av --delete /var/lib/searxng /mnt/nas/homeserver/var/lib/
        sudo rsync -av --delete /var/lib/cloudflared /mnt/nas/homeserver/var/lib/
        sudo rsync -av --delete /var/lib/filebrowser /mnt/nas/homeserver/var/lib/
        sudo rsync -av --delete /var/lib/portainer /mnt/nas/homeserver/var/lib/
        sudo rsync -av --delete /var/lib/vaultwarden /mnt/nas/homeserver/var/lib/
        sudo rsync -av --delete /var/lib/qbittorrent /mnt/nas/homeserver/var/lib/
      }
    '';
  };
}
