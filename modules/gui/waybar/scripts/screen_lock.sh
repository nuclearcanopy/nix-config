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

# Restore on every exit path, not just the happy one. This runs in waybar's
# cgroup, so a waybar-output-watcher restart (any real output change during
# the 30-minute window) SIGTERMs it mid-wait; the trap used to remove only
# the pidfile, leaving "input type:keyboard events disabled" in place and the
# keyboard dead in sway until the user middle-clicked caffeine again.
restore() {
  swaymsg 'input type:keyboard events enabled' >/dev/null 2>&1 || true
  swaymsg 'output * power on' >/dev/null 2>&1 || true
  rm -f "$LOCKFILE"
}
trap restore EXIT
# Explicit, so bash runs the EXIT trap instead of dying on the signal.
trap 'exit 143' TERM
trap 'exit 130' INT
trap 'exit 129' HUP

swaymsg 'output * power off' >/dev/null
swaymsg 'input type:keyboard events disabled' >/dev/null

@screenLockWait@ 3 1800
