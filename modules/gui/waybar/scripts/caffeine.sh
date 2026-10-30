#!/usr/bin/env bash
# Toggle caffeine mode: prevent idle/sleep and lid-close suspend.
# Uses systemd-inhibit to block idle, sleep, and the logind lid handler so
# the laptop keeps running with the lid shut (for agents running in a bag).
#
# The inhibitor runs in its own transient user unit rather than backgrounded
# from here. An on-click runs inside waybar.service's cgroup (KillMode=mixed),
# so a waybar restart SIGKILLed it (journal, 2026-10-30 15:18:41) while the
# pidfile in /run/user survived: the module then read "Caffeine OFF" and
# logind's lid handler silently re-engaged, suspending the laptop in a bag.
# waybar-output-watcher restarts waybar on any real output change, so this
# needed no crash to trigger.
PIDFILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/waybar-caffeine.pid"
UNIT=waybar-caffeine

active() { systemctl --user is-active --quiet "$UNIT.service"; }

start() {
  systemd-run --user --quiet --collect --unit="$UNIT" \
    systemd-inhibit --what=idle:sleep:handle-lid-switch --who=waybar-caffeine \
    --why="Caffeine mode active" --mode=block \
    sleep infinity || return 1

  # caffeine-watchdog runs as root and keys off this pidfile, so keep
  # publishing the inhibitor's pid. The unit is the source of truth here.
  i=0
  while [ "$i" -lt 20 ]; do
    pid=$(systemctl --user show -p MainPID --value "$UNIT.service" 2>/dev/null)
    if [ -n "$pid" ] && [ "$pid" != 0 ]; then
      printf '%s\n' "$pid" > "$PIDFILE"
      return 0
    fi
    i=$((i + 1))
    sleep 0.1
  done
  return 0
}

stop() {
  systemctl --user stop "$UNIT.service" 2>/dev/null || true
  rm -f "$PIDFILE"
}

if [ "$1" = "toggle" ]; then
  if active; then stop; else start; fi
  pkill -RTMIN+8 waybar
  exit
fi

if active; then
  printf '{"text":"CAF","class":"active","tooltip":"Caffeine ON: screen + lid will not sleep"}\n'
else
  rm -f "$PIDFILE" 2>/dev/null
  printf '{"text":"CAF","tooltip":"Caffeine OFF"}\n'
fi
