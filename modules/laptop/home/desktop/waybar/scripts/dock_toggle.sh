#!/usr/bin/env bash
# Toggle "docked / mac-mini" mode on nidhoggr:
#   - disable eDP-1 so only the external monitor is active
#   - hold a systemd-inhibit lock on handle-lid-switch so closing the lid
#     does not suspend (logind's HandleLidSwitch=suspend is overridden while
#     the lock is held)
PIDFILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/waybar-dock.pid"

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  kill "$(cat "$PIDFILE")"
  rm -f "$PIDFILE"
  swaymsg 'output eDP-1 enable' >/dev/null
else
  swaymsg 'output eDP-1 disable' >/dev/null
  systemd-inhibit --what=handle-lid-switch --who=waybar-dock \
    --why="Docked mode: lid close ignored" --mode=block \
    sleep infinity &
  echo $! > "$PIDFILE"
fi

pkill -RTMIN+10 waybar 2>/dev/null || true
