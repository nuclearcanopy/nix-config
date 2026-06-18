#!/usr/bin/env bash
PIDFILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/waybar-dock.pid"

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  printf '{"text":"EXT","class":"active","tooltip":"Docked: internal display off, lid close ignored"}\n'
else
  rm -f "$PIDFILE" 2>/dev/null
  printf '{"text":"EXT","tooltip":"Docked mode OFF"}\n'
fi
