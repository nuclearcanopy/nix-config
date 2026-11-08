#!/usr/bin/env bash
# reboot-log: on every boot, append the previous session's shutdown context
# to /var/log/reboot-history.log so we can tell scheduled reboots from
# watchdog-triggered reboots from hard-crashes.
#
# What we capture (best-effort -- journal may not have everything if the
# crash was hard enough to lose the last few seconds):
#   - current boot ID + previous boot ID
#   - previous session's uptime and last-15-line dmesg
#   - previous session's kernel oops/panic/error grep
#   - which watchdogs fired last (their state files, if journal has the log)
#   - shutdown reason if the previous session logged one (systemctl reboot etc)
set -u

LOG=/var/log/reboot-history.log
NOW=$(date -Is)

# journalctl --list-boots gives us "<offset> <boot-id> <first> <last>"
# offset 0 = current boot, -1 = previous, etc.
prev_boot=$(journalctl --list-boots --no-pager -q 2>/dev/null | awk '$1=="-1"{print $2; exit}')

{
  echo "================================================================"
  echo "boot recorded at $NOW"
  echo "current boot id: $(cat /proc/sys/kernel/random/boot_id 2>/dev/null)"
  echo "previous boot id: ${prev_boot:-<none>}"
  echo "kernel: $(uname -r)"
  echo

  if [ -n "${prev_boot:-}" ]; then
    prev_first=$(journalctl --list-boots --no-pager -q 2>/dev/null | awk '$1=="-1"{print $3, $4}')
    prev_last=$(journalctl --list-boots --no-pager -q 2>/dev/null | awk '$1=="-1"{print $5, $6}')
    echo "previous session:"
    echo "  started: $prev_first"
    echo "  ended:   $prev_last"
    echo

    echo "--- previous session: shutdown reason (systemd/reboot/panic hints) ---"
    journalctl -b -1 --no-pager -q 2>/dev/null | tail -300 | grep -iE \
      "systemd-reboot|reboot request|systemctl reboot|kernel panic|oops|BUG:|watchdog|hardware watchdog|out of memory|oom-killer|FATAL" | tail -30 || echo "  (no relevant lines)"
    echo

    echo "--- previous session: last 20 kernel log lines ---"
    journalctl -b -1 -k --no-pager -q 2>/dev/null | tail -20 || echo "  (none)"
    echo

    echo "--- previous session: last 10 server-watchdog + net-watchdog entries ---"
    journalctl -b -1 --no-pager -q -u server-watchdog.service -u net-watchdog.service 2>/dev/null | tail -20 || echo "  (none)"
  else
    echo "(no previous boot in journal)"
  fi

  echo
  echo "--- disk state at boot ---"
  df -h / /boot 2>/dev/null | grep -v Filesystem
  echo
} >> "$LOG"

# Also emit a single-line summary to the journal so a `journalctl -u reboot-log`
# gives a quick view without needing to read the persistent file.
prev_summary=$(journalctl -b -1 --no-pager -q 2>/dev/null | tail -200 | grep -iE "systemd-reboot|systemctl reboot|kernel panic|oops|watchdog|oom-killer" | tail -1)
echo "reboot-log: previous session ended -- ${prev_summary:-<no reason detected>}"

exit 0
