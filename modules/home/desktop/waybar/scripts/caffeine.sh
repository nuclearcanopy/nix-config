#!/usr/bin/env bash
# Toggle caffeine mode: prevent swayidle from dimming/sleeping the screen.
# Uses systemd-inhibit to block idle/sleep while active.
PIDFILE="/tmp/waybar-caffeine.pid"

toggle() {
  if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    kill "$(cat "$PIDFILE")"
    rm -f "$PIDFILE"
  else
    systemd-inhibit --what=idle:sleep --who=waybar-caffeine \
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
  printf '{"text":"CAF","class":"active","tooltip":"Caffeine ON: screen will not sleep"}\n'
else
  rm -f "$PIDFILE" 2>/dev/null
  printf '{"text":"CAF","tooltip":"Caffeine OFF"}\n'
fi
