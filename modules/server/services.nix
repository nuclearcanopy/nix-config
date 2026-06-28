{
  # Container stack + supporting services: navidrome (music streaming),
  # vaultwarden (password manager), searxng (privacy search), filebrowser,
  # portainer, cloudflared (tunnel). mscd-api (custom Flask download API).
  # Daily NAS backup with 7-day snapshot retention, 15-min NAS→SSD sync for
  # navidrome music cache, daily 05:00 system reboot.
  nixos.modules.server-services = { config, pkgs, lib, username, ... }:

    let
      dockerNet = "cloudflared-net";
      mscdZsh = pkgs.writeText "mscd.zsh" (builtins.readFile ./scripts/mscd.zsh);
      mscdApi = pkgs.writeTextFile {
        name = "mscd_api.py";
        text = builtins.replaceStrings
          [ "/etc/nixos/mscd.zsh" ]
          [ "${mscdZsh}" ]
          (builtins.readFile ./scripts/mscd_api.py);
        executable = true;
      };
      # cloudflared config holds the public hostnames (one per tunneled service);
      # encrypted as an agenix secret so the public repo never reveals them.
      searxngConfig = pkgs.writeText "searxng-settings.yml" (builtins.readFile ./configs/searxng-settings.yml);
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
              # 6h instead of 1h: hourly scans were contending with the SQLite
              # cache and disk I/O during playback.
              ND_SCANSCHEDULE = "6h";
              ND_LASTFM_ENABLED = "true";

              # Keep at default "info": navidrome-boost.service watches for
              # "Streaming file" log lines to flip the CPU governor, and those
              # only appear at info level. The bulk of the old log volume was
              # the suspended Last.fm error storm, not normal info output.
              ND_LOGLEVEL = "info";

              # On-disk transcoding cache so re-plays of the same opus encode are free.
              ND_TRANSCODINGCACHESIZE = "5GB";
              ND_IMAGECACHESIZE = "500MB";

              # Default downsampling target when a client passes maxBitRate. Opus is
              # the right call for cellular over cloudflared.
              ND_DEFAULTDOWNSAMPLINGFORMAT = "opus";

              # Long-lived sessions: flaky-network clients shouldn't re-auth mid-album.
              ND_SESSIONTIMEOUT = "168h";

              ND_ENABLEDOWNLOADS = "true";
            };
            environmentFiles = [
              # Agenix env file still holds the OLD suspended Last.fm key.
              config.age.secrets.homeserver-navidrome-env.path
              # Local override: docker reads --env-file args in order, last wins for dupes.
              # File is root:root mode 600, written out-of-band so the new Last.fm key
              # never leaks into the public repo. Migrate back into the agenix secret
              # next time you rebuild from kuraokami (only kuraokami can decrypt it).
              "/var/lib/navidrome/lastfm.env"
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
              "${config.age.secrets.homeserver-cloudflared-config.path}:/etc/cloudflared/config.yml:ro"
              "${config.age.secrets.homeserver-cloudflared-credentials.path}:/etc/cloudflared/credentials.json:ro"
            ];
            # --protocol=quic and 4 parallel tunnel connections: QUIC handles
            # cellular packet loss much better than http2, and 4 conns lets
            # navidrome streams parallelise instead of head-of-line blocking
            # on a single HTTP/2 stream.
            cmd = [
              "tunnel"
              "--config" "/etc/cloudflared/config.yml"
              "--protocol" "quic"
              "--ha-connections" "4"
              "run"
            ];
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
        # C+ copies (overwriting) so the container gets a writable file.
        "C+ /var/lib/searxng/settings.yml 0644 root root - ${searxngConfig}"
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

      # Force docker-navidrome to restart on any exit. The oci-containers default
      # passes --rm and exits the systemd unit; without this, a crash takes the
      # service down until the next boot.
      systemd.services.docker-navidrome.serviceConfig = {
        Restart = lib.mkForce "always";
        RestartSec = "5s";
      };

      # CPU governor boost while navidrome is streaming. Tails journald for
      # navidrome stream/scan activity; on each hit, sets every CPU to
      # `performance` and refreshes a last-activity timestamp. A second loop
      # drops back to `powersave` once 120s have passed with no activity.
      #
      # Why bother: the i5-5200U sits at 800 MHz under the `powersave` governor;
      # initial HWP ramp-up adds tens of ms to first-byte on each range request,
      # which is exactly when a client buffer-underruns and gives up.
      systemd.services.navidrome-boost = {
        description = "Boost CPU governor to performance while Navidrome is streaming";
        after = [ "docker-navidrome.service" ];
        wants = [ "docker-navidrome.service" ];
        wantedBy = [ "multi-user.target" ];
        path = [ pkgs.systemd pkgs.coreutils pkgs.gnugrep ];
        serviceConfig = {
          Type = "simple";
          Restart = "always";
          RestartSec = "10s";
          # Needs root to write scaling_governor.
          User = "root";
        };
        script = ''
          set -u
          STATE=/run/navidrome-boost/last-activity
          TIMEOUT=120
          BOOST=performance
          IDLE=powersave

          mkdir -p /run/navidrome-boost
          # Seed timestamp far in the past so the watchdog drops to IDLE
          # immediately if no activity arrives.
          echo 0 > "$STATE"

          set_gov() {
            for c in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
              [ -w "$c" ] && echo "$1" > "$c" || true
            done
          }

          # Start at IDLE; reader will boost on first activity.
          set_gov "$IDLE"

          # Reader: tail navidrome's journal and mark activity.
          (
            journalctl -fu docker-navidrome.service -n 0 --output=cat 2>&1 |
            while IFS= read -r line; do
              case "$line" in
                *"Streaming file"*|*"GET /rest/stream"*|*"GET /rest/download"*|*"Scanner"*)
                  date +%s > "$STATE"
                  set_gov "$BOOST"
                  ;;
              esac
            done
          ) &
          READER_PID=$!

          # On shutdown, drop back to idle governor and stop the reader.
          trap 'set_gov "$IDLE"; kill $READER_PID 2>/dev/null; exit 0' TERM INT

          # Watchdog: drop to idle governor after TIMEOUT seconds of no activity.
          while true; do
            sleep 30
            last=$(cat "$STATE" 2>/dev/null || echo 0)
            now=$(date +%s)
            if [ $((now - last)) -gt $TIMEOUT ]; then
              set_gov "$IDLE"
            fi
            # If the reader died, restart the unit.
            if ! kill -0 $READER_PID 2>/dev/null; then
              exit 1
            fi
          done
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

      # Primary sync: NAS → local SSD (NAS is source of truth, SSD is fast cache).
      # Runs frequently to keep local SSD up-to-date for fast Navidrome streaming.
      systemd.services.navidrome-sync-from-nas = {
        description = "Sync Navidrome music from NAS to local SSD cache";
        after = [ "mnt-nas.mount" ];
        serviceConfig = {
          Type = "oneshot";
          User = username;
        };
        script = ''
          set -e

          mkdir -p /home/${username}/Navidrome/music/Web
          mkdir -p /home/${username}/Navidrome/music/Bought

          ${pkgs.rsync}/bin/rsync -a --delete \
            /mnt/nas/Navidrome/music/ \
            /home/${username}/Navidrome/music/

          if [[ -f /mnt/nas/Navidrome/cookies.txt ]]; then
            cp /mnt/nas/Navidrome/cookies.txt /home/${username}/Navidrome/cookies.txt
          fi

          echo "Navidrome sync from NAS completed at $(date)"
        '';
      };

      systemd.timers.navidrome-sync-from-nas = {
        description = "Timer for Navidrome NAS to SSD sync";
        wantedBy = [ "timers.target" ];
        timerConfig = {
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

      # Trigger systemd-reboot.target directly; no wrapper service needed.
      systemd.timers.systemd-reboot = {
        description = "Daily system reboot at 5 AM";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "*-*-* 05:00:00";
          Persistent = true;
        };
      };
    };
}
