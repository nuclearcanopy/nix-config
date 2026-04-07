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
  environment.etc."cloudflared/config.yml".source = cloudflaredConfig;
  environment.etc."searxng/settings.yml".source = searxngConfig;

  virtualisation.docker.enable = true;

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
        volumes = [ "/etc/searxng:/etc/searxng:ro" ];
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
        volumes = [ "/etc/cloudflared:/etc/cloudflared:ro" ];
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
