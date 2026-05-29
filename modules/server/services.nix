{ config, pkgs, lib, username, ... }:

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
          "/home/${username}/Navidrome/music:/music:ro"
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
          SEARXNG_BASE_URL = "https://searxng.local/";
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
    "d /var/lib/filebrowser 0755 root root -"
    "d /var/lib/vaultwarden 0755 root root -"
    "d /var/lib/navidrome 0755 root root -"
    "d /var/lib/portainer 0755 root root -"
    "d /var/lib/searxng 0755 root root -"
    # Declaratively deploy SearXNG config on each boot; replaces ExecStartPre cp/chmod.
    # C+ copies (overwriting) so the container gets a writable file, not a store symlink.
    "C+ /var/lib/searxng/settings.yml 0644 root root - ${searxngConfig}"
    # Local Navidrome music library on SSD for fast access
    "d /home/${username}/Navidrome 0755 homeserver users -"
    "d /home/${username}/Navidrome/music 0755 homeserver users -"
    "d /home/${username}/Navidrome/music/Web 0755 homeserver users -"
    "d /home/${username}/Navidrome/music/Bought 0755 homeserver users -"
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
    serviceConfig.ExecStartPre = [ "${pkgs.coreutils}/bin/sleep 10" ];
  };

  systemd.services.mscd-api = {
    description = "MSCD Web API for remote music downloads";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      User = username;
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

      SNAPSHOT_DIR="/mnt/nas/homeserver/snapshots/$(date +%Y-%m-%d)"

      mkdir -p /mnt/nas/homeserver/etc
      mkdir -p /mnt/nas/homeserver/var/lib
      mkdir -p "$SNAPSHOT_DIR"

      ${pkgs.rsync}/bin/rsync -av --delete --exclude='.git' \
        --backup --backup-dir="$SNAPSHOT_DIR/nix-config" \
        /home/homeserver/nix-config /mnt/nas/homeserver/etc/
      ${pkgs.rsync}/bin/rsync -av --delete --exclude='cache' \
        --backup --backup-dir="$SNAPSHOT_DIR/navidrome" \
        /var/lib/navidrome /mnt/nas/homeserver/var/lib/
      ${pkgs.rsync}/bin/rsync -av --delete \
        --backup --backup-dir="$SNAPSHOT_DIR/filebrowser" \
        /var/lib/filebrowser /mnt/nas/homeserver/var/lib/
      ${pkgs.rsync}/bin/rsync -av --delete \
        --backup --backup-dir="$SNAPSHOT_DIR/portainer" \
        /var/lib/portainer /mnt/nas/homeserver/var/lib/
      ${pkgs.rsync}/bin/rsync -av --delete \
        --backup --backup-dir="$SNAPSHOT_DIR/vaultwarden" \
        /var/lib/vaultwarden /mnt/nas/homeserver/var/lib/

      # prune snapshots older than 7 days
      ${pkgs.findutils}/bin/find /mnt/nas/homeserver/snapshots \
        -maxdepth 1 -type d -mtime +7 -exec rm -rf {} +

      echo "Backup completed successfully at $(date)"
    '';
  };

  # Primary sync: NAS → local SSD (NAS is source of truth, SSD is fast cache)
  # This runs frequently to keep local SSD up-to-date for fast Navidrome streaming
  systemd.services.navidrome-sync-from-nas = {
    description = "Sync Navidrome music from NAS to local SSD cache";
    after = [ "mnt-nas.mount" ];
    serviceConfig = {
      Type = "oneshot";
      User = username;
    };
    script = ''
      set -e

      # Ensure local directories exist
      mkdir -p /home/${username}/Navidrome/music/Web
      mkdir -p /home/${username}/Navidrome/music/Bought

      # Sync NAS → local (--delete keeps them identical)
      ${pkgs.rsync}/bin/rsync -a --delete \
        /mnt/nas/Navidrome/music/ \
        /home/${username}/Navidrome/music/

      # Copy cookies file if it exists on NAS
      if [[ -f /mnt/nas/Navidrome/cookies.txt ]]; then
        cp /mnt/nas/Navidrome/cookies.txt /home/${username}/Navidrome/cookies.txt
      fi

      echo "Navidrome sync from NAS completed at $(date)"
    '';
  };

  # Timer for NAS → SSD sync (runs every 15 minutes to keep SSD cache fresh)
  systemd.timers.navidrome-sync-from-nas = {
    description = "Timer for Navidrome NAS to SSD sync";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      # Sync every 15 minutes and 2 min after boot
      OnCalendar = "*:00/15";
      OnBootSec = "2min";
      Persistent = true;
    };
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

  # Trigger the built-in systemd-reboot.target directly — no wrapper service needed.
  systemd.timers.systemd-reboot = {
    description = "Daily system reboot at 5 AM";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 05:00:00";
      Persistent = true;
    };
  };
}
