#!/usr/bin/env bash
# Middle-click on caffeine: blank the display and swallow the next 3
# physical keypresses so an accidental wake (bag pressure, etc.) doesn't
# type into whatever's focused. Re-enables input and re-powers the display
# on the 3rd keydown, or after a 30-minute safety timeout if the watcher
# never sees one (so a bug here can't permanently eat the keyboard).
set -u
LOCKFILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/waybar-screen-lock.pid"

if [ -f "$LOCKFILE" ] && kill -0 "$(cat "$LOCKFILE")" 2>/dev/null; then
  exit 0
fi
echo $$ > "$LOCKFILE"
trap 'rm -f "$LOCKFILE"' EXIT

swaymsg 'output * power off' >/dev/null
swaymsg 'input type:keyboard events disabled' >/dev/null

@screenLockWait@ 3 1800

swaymsg 'input type:keyboard events enabled' >/dev/null
swaymsg 'output * power on' >/dev/null
