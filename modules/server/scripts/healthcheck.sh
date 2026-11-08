#!/usr/bin/env bash
# server watchdog: health-check the core services and escalate recovery.
#
# invoked every 2 min by server-watchdog.timer. failure counters live in
# /run (tmpfs) on purpose: a reboot always starts from a clean slate, so a
# permanently-broken service can never turn into a boot loop.
#
# escalation ladder per service (checks are ~2 min apart):
#   1 fail   -> restart just that container unit
#   >=2 fail -> the light restart didn't stick: bounce the whole docker stack
#   >=6 fail -> give up and reboot the box
#
# dependency prechecks: some containers can only be healthy if an external
# dependency is up, and no amount of restarting -- let alone rebooting the box
# -- can fix that dependency:
#   - cloudflared depends on external network egress. if egress is dead,
#     restarting only extends downtime (fresh handshakes on a broken transport);
#     net-watchdog handles the transport layer. if egress is ALIVE but the
#     tunnel is still down, the transport works for plain traffic while the
#     tunnel's QUIC path to the Cloudflare edge is being dropped -- the classic
#     symptom of a flapping Mullvad relay (QUIC-over-WireGuard is UDP-in-UDP and
#     dies first when the relay gets lossy). A container restart or box reboot
#     only re-dials the SAME relay and loops (this rebooted the box repeatedly
#     on 2026-09-06). So for an egress-dep service we add a rung BELOW reboot:
#     cycle Mullvad (`mullvad reconnect`) for a fresh handshake/relay, then
#     re-dial the tunnel. Reboot stays as the last resort if fresh relays keep
#     failing too.
#   - filebrowser bind-mounts /mnt/nas/filebrowser. if the NAS is unreachable
#     the container exits 125 on every start; rebooting the box CANNOT remount a
#     NAS, so a NAS-down filebrowser must never escalate. systemd Restart=always
#     keeps retrying the mount on its own cadence until the NAS comes back.
# in both cases, when the dependency is down we skip the restart and do NOT
# increment the failcount, so the escalation ladder is never climbed.
set -u

STATE=/run/server-watchdog
mkdir -p "$STATE"

RESTART_AT=2     # consecutive fails before escalating to a full docker-stack bounce
REBOOT_AT=6      # consecutive fails before GIVE-UP (auto-reboot disabled; see reboot_now)

# every container unit, restarted together during a stack bounce.
CONTAINERS="docker-navidrome docker-filebrowser docker-portainer docker-cloudflared"

log() { echo "server-watchdog: $*"; }

fail_count() { cat "$STATE/$1.fails" 2>/dev/null || echo 0; }
set_count()  { echo "$2" >"$STATE/$1.fails"; }

# Auto-reboot on downed services is disabled by request: a crashed service must
# never take the whole box down. We log loudly and reset the counter so the
# ladder keeps retrying restarts instead of climbing toward a reboot.
reboot_now() {
  log "GIVE-UP: $1 -- auto-reboot disabled, leaving the box up (restarts will keep retrying)"
  exit 0
}

bounce_stack() {
  log "escalating: restarting docker daemon + network + all containers"
  systemctl restart docker.service || true
  systemctl restart init-docker-network.service || true
  for u in $CONTAINERS; do
    systemctl restart "$u.service" || true
  done
}

# true if we can reach the wider internet through the current transport.
# used as a precheck before touching cloudflared, so a Mullvad/WiFi flap
# doesn't trigger a container restart that only makes recovery slower.
egress_alive() {
  curl -fsS --max-time 5 -o /dev/null https://1.1.1.1/ 2>/dev/null || \
  curl -fsS --max-time 5 -o /dev/null https://cloudflare.com/cdn-cgi/trace 2>/dev/null
}

# true if the NAS is actually mounted and readable. /mnt/nas is autofs, so it
# always looks like a mountpoint even when the backing CIFS/NFS share is dead
# (`ls` then fails with "no such device"). a readability probe is the only
# reliable signal; timeout guards against a hung (not merely dead) backend.
nas_alive() {
  timeout 6 ls /mnt/nas >/dev/null 2>&1
}

# --- 1. docker daemon liveness -------------------------------------------
# a wedged daemon takes every container down, so check it first and hardest.
if ! timeout 20 docker ps >/dev/null 2>&1; then
  n=$(($(fail_count docker) + 1))
  set_count docker "$n"
  log "docker daemon unresponsive (fail $n)"
  [ "$n" -ge "$REBOOT_AT" ] && reboot_now "docker daemon wedged $n consecutive checks"
  systemctl restart docker.service || true
  # let the next tick re-evaluate the containers once the daemon is back.
  exit 0
fi
set_count docker 0

# --- 2. per-service HTTP health ------------------------------------------
# args: name  health-url  container-unit  [dependency: egress|nas|""]
# the optional dependency names an external prereq that a restart/reboot can't
# fix; if it's down we skip and do NOT increment the failcount (see header).
check() {
  name="$1"
  url="$2"
  unit="$3"
  dep="${4:-}"

  if curl -fsS --max-time 12 -o /dev/null "$url"; then
    set_count "$name" 0
    return
  fi

  case "$dep" in
    egress)
      if ! egress_alive; then
        log "$name unhealthy AND egress dead -- skipping restart (net-watchdog will handle)"
        return
      fi
      ;;
    nas)
      if ! nas_alive; then
        log "$name unhealthy AND NAS mount dead -- skipping restart (a reboot can't remount the NAS; Restart=always keeps retrying)"
        return
      fi
      ;;
    svc)
      # Plain systemd service (not a docker container), e.g. mscd-api. A hang
      # here is local to that one unit, so just restart it -- never bounce the
      # whole docker stack and never climb toward a reboot.
      n=$(($(fail_count "$name") + 1))
      set_count "$name" "$n"
      log "$name unhealthy at $url (fail $n) -- restarting $unit"
      systemctl restart "$unit.service" || true
      return
      ;;
  esac

  n=$(($(fail_count "$name") + 1))
  set_count "$name" "$n"
  log "$name unhealthy at $url (fail $n)"

  if [ "$n" -ge "$REBOOT_AT" ]; then
    reboot_now "$name unhealthy $n consecutive checks"
  elif [ "$dep" = egress ]; then
    # Egress is alive (checked above) but the tunnel is still down. The server no
    # longer tunnels through Mullvad, so cloudflared dials the Cloudflare edge on
    # the real ISP IP -- a plain container re-dial is the only lever here.
    log "$name: restarting $unit"
    systemctl restart "$unit.service" || true
  elif [ "$n" -ge "$RESTART_AT" ]; then
    bounce_stack
  else
    log "$name: restarting $unit"
    systemctl restart "$unit.service" || true
  fi
}

check navidrome   http://127.0.0.1:4533/           docker-navidrome
check filebrowser http://127.0.0.1:8081/health     docker-filebrowser   nas
check portainer   http://127.0.0.1:9000/api/status docker-portainer
check cloudflared http://127.0.0.1:44483/ready     docker-cloudflared   egress
check mscd-api    http://127.0.0.1:8090/health     mscd-api             svc

exit 0
