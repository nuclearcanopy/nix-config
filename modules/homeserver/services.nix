{ config, pkgs, lib, ... }:

let
  dockerNet = "cloudflared-net";
  mscdZsh = pkgs.writeText "mscd.zsh" (builtins.readFile ../../scripts/mscd.zsh);
  mscdApi = pkgs.writeTextFile {
    name = "mscd_api.py";
    text = builtins.replaceStrings
      [ "/etc/nixos/mscd.zsh" ]
      [ "${mscdZsh}" ]
      (builtins.readFile ../../scripts/mscd_api.py);
    executable = true;
  };
  cloudflaredConfig = pkgs.writeText "cloudflared-config.yml" (builtins.readFile ../../configs/cloudflared.yml);
  searxngConfig = pkgs.writeText "searxng-settings.yml" (builtins.readFile ../../configs/searxng-settings.yml);
in
{
  virtualisation.docker.enable = true;

  virtualisation.oci-containers = {
    backend = "docker";

    containers = {
      navidrome = {
        image = "deluan/navidrome:latest";
        ports = [ "4533:4533" ];
        volumes = [
          "/var/lib/navidrome/data:/data"
          "/home/homeserver/Navidrome/music:/music:ro"
        ];
        environment = {
          ND_SCANSCHEDULE = "1h";
          ND_LASTFM_ENABLED = "true";
          ND_LASTFM_ISENABLED = "true";
        };
        environmentFiles = [
          config.age.secrets.homeserver-navidrome-env.path
        ];
        extraOptions = [ "--network=${dockerNet}" ];
      };

      vaultwarden = {
        image = "vaultwarden/server:latest";
        ports = [ "127.0.0.1:8000:80" ];
        volumes = [ "/var/lib/vaultwarden:/data" ];
        environment = {
          DOMAIN = "https://vaultwarden.local";
          SIGNUPS_ALLOWED = "false";
        };
        extraOptions = [ "--network=${dockerNet}" ];
      };

      searxng = {
        image = "searxng/searxng:latest";
        ports = [ "8080:8080" ];
        volumes = [ "/var/lib/searxng:/etc/searxng" ];
        environment = {
          SEARXNG_BASE_URL = "https://search.nuclearcanopy.xyz/";
          SEARXNG_SETTINGS_PATH = "/etc/searxng/settings.yml";
        };
        environmentFiles = [
          config.age.secrets.homeserver-searxng-env.path
        ];
        extraOptions = [ "--network=${dockerNet}" ];
      };

      filebrowser = {
        image = "filebrowser/filebrowser:latest";
        ports = [ "8081:80" ];
        volumes = [
          "/mnt/nas/filebrowser:/srv"
          "/var/lib/filebrowser:/database"
        ];
        extraOptions = [ "--network=${dockerNet}" ];
      };

      portainer = {
        image = "portainer/portainer-ce:latest";
        ports = [ "9000:9000" ];
        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock"
          "/var/lib/portainer:/data"
        ];
        extraOptions = [ "--network=${dockerNet}" ];
      };

      cloudflared = {
        image = "cloudflare/cloudflared:latest";
        volumes = [
          "${cloudflaredConfig}:/etc/cloudflared/config.yml:ro"
          "${config.age.secrets.homeserver-cloudflared-credentials.path}:/etc/cloudflared/credentials.json:ro"
        ];
        cmd = [ "tunnel" "--config" "/etc/cloudflared/config.yml" "run" ];
        extraOptions = [ "--network=${dockerNet}" ];
      };
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/lidarr 0755 root root -"
    "d /var/lib/prowlarr 0755 root root -"
    "d /var/lib/filebrowser 0755 root root -"
    "d /var/lib/vaultwarden 0755 root root -"
    "d /var/lib/navidrome 0755 root root -"
    "d /var/lib/portainer 0755 root root -"
    "d /var/lib/searxng 0755 root root -"
    # Local Navidrome music library on SSD for fast access
    "d /home/homeserver/Navidrome 0755 homeserver users -"
    "d /home/homeserver/Navidrome/music 0755 homeserver users -"
    "d /home/homeserver/Navidrome/music/Web 0755 homeserver users -"
    "d /home/homeserver/Navidrome/music/Bought 0755 homeserver users -"
  ];

  systemd.services.init-docker-network = {
    description = "Create Docker network for Cloudflared";
    after = [ "network.target" "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    script = ''
      ${pkgs.docker}/bin/docker network inspect ${dockerNet} >/dev/null 2>&1 || \
      ${pkgs.docker}/bin/docker network create ${dockerNet} || true
    '';
  };

  systemd.services.docker-searxng = {
    after = [
      "network-online.target"
      "mullvad-autoconnect.service"
      "init-docker-network.service"
    ];
    wants = [ "network-online.target" ];
    serviceConfig.ExecStartPre = [
      "${pkgs.coreutils}/bin/sleep 10"
      # Copy settings.yml to writable volume (SearXNG needs write access to /etc/searxng)
      "${pkgs.coreutils}/bin/cp -f ${searxngConfig} /var/lib/searxng/settings.yml"
      "${pkgs.coreutils}/bin/chmod 644 /var/lib/searxng/settings.yml"
    ];
  };

  systemd.services.mscd-api = {
    description = "MSCD Web API for remote music downloads";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      User = "homeserver";
      EnvironmentFile = [ config.age.secrets.homeserver-mscd-api-hash.path ];
      ExecStart = "${pkgs.python3.withPackages (ps: [ ps.mutagen ps.flask ])}/bin/python3 ${mscdApi}";
      Restart = "on-failure";
      RestartSec = "10s";
    };
    environment = {
      PYTHONUNBUFFERED = "1";
    };
  };

  systemd.services.backup-to-nas = {
    description = "Backup server configuration and data to NAS";
    after = [ "mnt-nas.mount" ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
    script = ''
      set -e

      mkdir -p /mnt/nas/homeserver/etc
      mkdir -p /mnt/nas/homeserver/var/lib

      ${pkgs.rsync}/bin/rsync -av --delete --exclude='.git' /home/homeserver/nix-config /mnt/nas/homeserver/etc/
      ${pkgs.rsync}/bin/rsync -av --delete --exclude='cache' /var/lib/navidrome /mnt/nas/homeserver/var/lib/
      ${pkgs.rsync}/bin/rsync -av --delete /var/lib/filebrowser /mnt/nas/homeserver/var/lib/
      ${pkgs.rsync}/bin/rsync -av --delete /var/lib/portainer /mnt/nas/homeserver/var/lib/
      ${pkgs.rsync}/bin/rsync -av --delete /var/lib/vaultwarden /mnt/nas/homeserver/var/lib/

      echo "Backup completed successfully at $(date)"
    '';
  };

  # Sync local Navidrome library TO NAS (backup local changes)
  systemd.services.navidrome-sync-to-nas = {
    description = "Sync local Navidrome music library to NAS";
    after = [ "mnt-nas.mount" ];
    serviceConfig = {
      Type = "oneshot";
      User = "homeserver";
    };
    script = ''
      set -e

      # Ensure NAS directories exist
      mkdir -p /mnt/nas/Navidrome/music

      # Sync local → NAS (preserves NAS files not on local with --update)
      ${pkgs.rsync}/bin/rsync -av --update \
        /home/homeserver/Navidrome/music/ \
        /mnt/nas/Navidrome/music/

      # Also sync cookies if it exists locally
      if [[ -f /home/homeserver/Navidrome/cookies.txt ]]; then
        cp /home/homeserver/Navidrome/cookies.txt /mnt/nas/Navidrome/cookies.txt
      fi

      echo "Navidrome sync to NAS completed at $(date)"
    '';
  };

  # Sync FROM NAS to local (for initial setup or recovery)
  systemd.services.navidrome-sync-from-nas = {
    description = "Sync Navidrome music library from NAS to local SSD";
    after = [ "mnt-nas.mount" ];
    serviceConfig = {
      Type = "oneshot";
      User = "homeserver";
    };
    script = ''
      set -e

      # Ensure local directories exist
      mkdir -p /home/homeserver/Navidrome/music

      # Sync NAS → local
      ${pkgs.rsync}/bin/rsync -av --progress \
        /mnt/nas/Navidrome/music/ \
        /home/homeserver/Navidrome/music/

      # Copy cookies file if it exists on NAS
      if [[ -f /mnt/nas/Navidrome/cookies.txt ]]; then
        cp /mnt/nas/Navidrome/cookies.txt /home/homeserver/Navidrome/cookies.txt
      fi

      echo "Navidrome sync from NAS completed at $(date)"
    '';
  };

  systemd.timers.navidrome-sync-to-nas = {
    description = "Timer for Navidrome library sync to NAS";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      # Sync every 30 minutes and 5 min after boot
      OnCalendar = "*:00/30";
      OnBootSec = "5min";
      Persistent = true;
    };
  };

  systemd.services.scheduled-reboot = {
    description = "Scheduled system reboot";
    serviceConfig.Type = "oneshot";
    script = ''
      ${pkgs.systemd}/bin/systemctl reboot
    '';
  };

  systemd.timers.backup-to-nas = {
    description = "Timer for automated NAS backups";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      OnBootSec = "15min";
      Persistent = true;
    };
  };

  systemd.timers.scheduled-reboot = {
    description = "Timer for daily system reboot at 5 AM";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 05:00:00";
      Persistent = true;
    };
  };
}
