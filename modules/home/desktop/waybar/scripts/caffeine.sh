#!/usr/bin/env bash
# Toggle caffeine mode: prevent idle/sleep and lid-close suspend.
# Uses systemd-inhibit to block idle, sleep, and the logind lid handler so
# the laptop keeps running with the lid shut (for agents running in a bag).
PIDFILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/waybar-caffeine.pid"

toggle() {
  if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    kill "$(cat "$PIDFILE")"
    rm -f "$PIDFILE"
  else
    systemd-inhibit --what=idle:sleep:handle-lid-switch --who=waybar-caffeine \
      --why="Caffeine mode active" --mode=block \
      sleep infinity &
    echo $! > "$PIDFILE"
  fi
  pkill -RTMIN+8 waybar
}

if [ "$1" = "toggle" ]; then
  toggle
  exit
fi

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  printf '{"text":"CAF","class":"active","tooltip":"Caffeine ON: screen + lid will not sleep"}\n'
else
  rm -f "$PIDFILE" 2>/dev/null
  printf '{"text":"CAF","tooltip":"Caffeine OFF"}\n'
fi
