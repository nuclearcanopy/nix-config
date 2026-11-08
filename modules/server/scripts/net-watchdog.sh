#!/usr/bin/env bash
# network watchdog: re-associate the NIC via NetworkManager when egress dies.
#
# invoked every 1 min by net-watchdog.timer. counters live in /run (tmpfs) so
# a reboot starts clean.
#
# escalation ladder (checks are ~1 min apart):
#   1-4 fail  -> log only, transient blip
#   5 fail    -> restart NetworkManager (fresh association)
# auto-reboot is disabled by request, and the box no longer tunnels through
# Mullvad, so there is no VPN rung either.
#
# egress is checked via HTTPS to 1.1.1.1 (Cloudflare).
set -u

STATE=/run/net-watchdog
mkdir -p "$STATE"
COUNT_FILE="$STATE/fails"

NM_AT=5

log() { echo "net-watchdog: $*"; }

count() { cat "$COUNT_FILE" 2>/dev/null || echo 0; }
set_count() { echo "$1" >"$COUNT_FILE"; }

# egress: ICMP is often blocked, so try HTTPS to a public IP.
egress_alive() {
  curl -fsS --max-time 5 -o /dev/null https://1.1.1.1/ 2>/dev/null || \
  curl -fsS --max-time 5 -o /dev/null https://8.8.8.8/ 2>/dev/null
}

if egress_alive; then
  n=$(count)
  if [ "$n" -gt 0 ]; then
    log "egress recovered after $n failed checks"
  fi
  set_count 0
  exit 0
fi

n=$(( $(count) + 1 ))
set_count "$n"
log "egress DEAD (consecutive fail $n)"

# Auto-reboot on dead egress is disabled by request. The box no longer tunnels
# through Mullvad, so the only recovery lever is re-associating the NIC via
# NetworkManager; past that we just keep logging and let the link recover.
if [ "$n" -ge "$NM_AT" ]; then
  log "escalating: restarting NetworkManager"
  systemctl restart NetworkManager.service || true
  exit 0
fi

# n < NM_AT: log only, treat as transient.
exit 0
