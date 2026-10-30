#!/usr/bin/env bash
# Toggle "docked / mac-mini" mode on nidhoggr:
#   - disable eDP-1 so only the external monitor is active
#   - hold a systemd-inhibit lock on handle-lid-switch so closing the lid
#     does not suspend (logind's HandleLidSwitch=suspend is overridden while
#     the lock is held)
#
# Transient user unit, not a backgrounded child: an on-click lands in
# waybar.service's cgroup (KillMode=mixed), so a waybar restart SIGKILLed the
# inhibitor. That was worse here than for caffeine, because `output eDP-1
# enable` only runs on the toggle-off path: eDP-1 stayed disabled while the
# module reported "Docked mode OFF", and it took two clicks to get the
# internal panel back with no indication why.
PIDFILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/waybar-dock.pid"
UNIT=waybar-dock

active() { systemctl --user is-active --quiet "$UNIT.service"; }

if active; then
  systemctl --user stop "$UNIT.service" 2>/dev/null || true
  rm -f "$PIDFILE"
  swaymsg 'output eDP-1 enable' >/dev/null
else
  swaymsg 'output eDP-1 disable' >/dev/null
  if systemd-run --user --quiet --collect --unit="$UNIT" \
      systemd-inhibit --what=handle-lid-switch --who=waybar-dock \
      --why="Docked mode: lid close ignored" --mode=block \
      sleep infinity; then
    # dock_mode.sh keys off the pidfile; keep it in sync with the unit.
    i=0
    while [ "$i" -lt 20 ]; do
      pid=$(systemctl --user show -p MainPID --value "$UNIT.service" 2>/dev/null)
      if [ -n "$pid" ] && [ "$pid" != 0 ]; then
        printf '%s\n' "$pid" > "$PIDFILE"
        break
      fi
      i=$((i + 1))
      sleep 0.1
    done
  else
    # Inhibitor refused to start, so don't leave the panel off with no lock.
    swaymsg 'output eDP-1 enable' >/dev/null
  fi
fi

pkill -RTMIN+10 waybar 2>/dev/null || true
