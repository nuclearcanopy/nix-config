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
set -u

STATE=/run/server-watchdog
mkdir -p "$STATE"

RESTART_AT=2   # consecutive fails before escalating to a full docker-stack bounce
REBOOT_AT=6    # consecutive fails before rebooting the machine

# every container unit, restarted together during a stack bounce.
CONTAINERS="docker-navidrome docker-filebrowser docker-portainer docker-cloudflared"

log() { echo "server-watchdog: $*"; }

fail_count() { cat "$STATE/$1.fails" 2>/dev/null || echo 0; }
set_count()  { echo "$2" >"$STATE/$1.fails"; }

reboot_now() {
  log "FATAL: $1 -- rebooting"
  systemctl reboot
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
# args: name  health-url  container-unit
check() {
  name="$1"
  url="$2"
  unit="$3"

  if curl -fsS --max-time 12 -o /dev/null "$url"; then
    set_count "$name" 0
    return
  fi

  n=$(($(fail_count "$name") + 1))
  set_count "$name" "$n"
  log "$name unhealthy at $url (fail $n)"

  if [ "$n" -ge "$REBOOT_AT" ]; then
    reboot_now "$name unhealthy $n consecutive checks"
  elif [ "$n" -ge "$RESTART_AT" ]; then
    bounce_stack
  else
    log "$name: restarting $unit"
    systemctl restart "$unit.service" || true
  fi
}

check navidrome   http://127.0.0.1:4533/          docker-navidrome
check filebrowser http://127.0.0.1:8081/health    docker-filebrowser
check portainer   http://127.0.0.1:9000/api/status docker-portainer
check cloudflared http://127.0.0.1:44483/ready     docker-cloudflared

exit 0
