{ config, pkgs, lib, ... }:

let
  mscdApi = pkgs.writeTextFile {
    name = "mscd_api.py";
    text = builtins.readFile ../../scripts/mscd_api.py;
    executable = true;
  };
in
{
  # Enable Docker
  virtualisation.docker.enable = true;

  # Docker containers
  virtualisation.oci-containers = {
    backend = "docker";

    containers = {
      navidrome = {
        image = "deluan/navidrome:latest";
        ports = [ "4533:4533" ];
        volumes = [
          "/var/lib/navidrome/data:/data"
          "/mnt/nas/Navidrome/music:/music:ro"
        ];
        environment = {
          ND_SCANSCHEDULE = "1h";
          ND_LASTFM_ENABLED = "true";
          # TODO: Move to agenix
          ND_LASTFM_APIKEY = "9a7691497f066c0ca8e66b6193ba5beb";
          ND_LASTFM_SECRET = "c48dfe426dd69edd5c8507c95a18d871";
          ND_LASTFM_ISENABLED = "true";
        };
        extraOptions = [ "--network=cloudflared-net" ];
      };

      vaultwarden = {
        image = "vaultwarden/server:latest";
        ports = [ "127.0.0.1:8000:80" ];
        volumes = [ "/var/lib/vaultwarden:/data" ];
        environment = {
          # TODO: Move to agenix
          DOMAIN = "https://vaultwarden.local";
          SIGNUPS_ALLOWED = "false";
        };
        extraOptions = [ "--network=cloudflared-net" ];
      };

      qbittorrent = {
        image = "lscr.io/linuxserver/qbittorrent:latest";
        ports = [ "8082:8082" ];
        volumes = [
          "/var/lib/qbittorrent:/config"
          "/mnt/nas/music:/music"
        ];
        environment = {
          PUID = "1000";
          PGID = "100";
          TZ = "Europe/Bucharest";
          WEBUI_PORT = "8082";
        };
        extraOptions = [ "--network=cloudflared-net" ];
      };

      searxng = {
        image = "searxng/searxng:latest";
        ports = [ "8080:8080" ];
        volumes = [ "/var/lib/searxng:/etc/searxng:rw" ];
        environment = {
          # TODO: Move to agenix
          SEARXNG_BASE_URL = "https://search.nuclearcanopy.xyz/";
          SEARXNG_SETTINGS_PATH = "/etc/searxng/settings.yml";
          SEARXNG_SECRET = "68b38378ab58f2dc7360e071c5578d30d81f3fe4251a9ccab6feacc7c297ec80";
        };
        extraOptions = [ "--network=cloudflared-net" ];
      };

      filebrowser = {
        image = "filebrowser/filebrowser:latest";
        ports = [ "8081:80" ];
        volumes = [
          "/mnt/nas/filebrowser:/srv"
          "/var/lib/filebrowser:/database"
        ];
        extraOptions = [ "--network=cloudflared-net" ];
      };

      portainer = {
        image = "portainer/portainer-ce:latest";
        ports = [ "9000:9000" ];
        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock"
          "/var/lib/portainer:/data"
        ];
        extraOptions = [ "--network=cloudflared-net" ];
      };

      cloudflared = {
        image = "cloudflare/cloudflared:latest";
        volumes = [ "/var/lib/cloudflared:/etc/cloudflared" ];
        cmd = [ "tunnel" "--config" "/etc/cloudflared/config.yml" "run" ];
        extraOptions = [ "--network=cloudflared-net" ];
      };
    };
  };

  # Create necessary directories
  systemd.tmpfiles.rules = [
    "d /var/lib/lidarr 0755 root root -"
    "d /var/lib/prowlarr 0755 root root -"
    "d /var/lib/qbittorrent 0755 root root -"
    "d /var/lib/searxng 0755 root root -"
    "d /var/lib/filebrowser 0755 root root -"
    "d /var/lib/vaultwarden 0755 root root -"
    "d /var/lib/navidrome 0755 root root -"
    "d /var/lib/portainer 0755 root root -"
    "d /var/lib/cloudflared 0755 root root -"
  ];

  # Docker network service
  systemd.services.init-docker-network = {
    description = "Create Docker network for Cloudflared";
    after = [ "network.target" "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    script = ''
      ${pkgs.docker}/bin/docker network inspect cloudflared-net >/dev/null 2>&1 || \
      ${pkgs.docker}/bin/docker network create cloudflared-net || true
    '';
  };

  # FIX: Make searxng wait for network to be fully ready
  # This fixes the DNS timeout issue on boot
  systemd.services.docker-searxng = {
    after = [
      "network-online.target"
      "mullvad-autoconnect.service"
      "init-docker-network.service"
    ];
    wants = [ "network-online.target" ];
    # Add a delay to ensure DNS is fully operational
    serviceConfig = {
      ExecStartPre = [
        "${pkgs.coreutils}/bin/sleep 10"
      ];
    };
  };

  # MSCD API service
  systemd.services.mscd-api = {
    description = "MSCD Web API for remote music downloads";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      User = "homeserver";
      ExecStart = "${pkgs.python3.withPackages (ps: [ ps.mutagen ps.flask ])}/bin/python3 ${mscdApi}";
      Restart = "on-failure";
      RestartSec = "10s";
    };
    environment = {
      PYTHONUNBUFFERED = "1";
    };
  };

  # Backup to NAS service
  systemd.services.backup-to-nas = {
    description = "Backup server configuration and data to NAS";
    after = [ "mnt-nas.mount" ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
    script = ''
      set -e

      # Ensure NAS backup directories exist
      mkdir -p /mnt/nas/homeserver/etc
      mkdir -p /mnt/nas/homeserver/var/lib

      # Backup using rsync
      ${pkgs.rsync}/bin/rsync -av --delete /home/homeserver/nix-config /mnt/nas/homeserver/etc/
      ${pkgs.rsync}/bin/rsync -av --delete --exclude='cache' /var/lib/navidrome /mnt/nas/homeserver/var/lib/
      ${pkgs.rsync}/bin/rsync -av --delete /var/lib/searxng /mnt/nas/homeserver/var/lib/
      ${pkgs.rsync}/bin/rsync -av --delete /var/lib/cloudflared /mnt/nas/homeserver/var/lib/
      ${pkgs.rsync}/bin/rsync -av --delete /var/lib/filebrowser /mnt/nas/homeserver/var/lib/
      ${pkgs.rsync}/bin/rsync -av --delete /var/lib/portainer /mnt/nas/homeserver/var/lib/
      ${pkgs.rsync}/bin/rsync -av --delete /var/lib/vaultwarden /mnt/nas/homeserver/var/lib/
      ${pkgs.rsync}/bin/rsync -av --delete /var/lib/qbittorrent /mnt/nas/homeserver/var/lib/

      echo "Backup completed successfully at $(date)"
    '';
  };

  # Scheduled reboot service
  systemd.services.scheduled-reboot = {
    description = "Scheduled system reboot";
    serviceConfig = {
      Type = "oneshot";
    };
    script = ''
      ${pkgs.systemd}/bin/systemctl reboot
    '';
  };

  # Timers
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
