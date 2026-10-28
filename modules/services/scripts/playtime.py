"""Cumulative powered-on time ("playtime") for this machine.

Counts seconds the machine is actually running. CLOCK_MONOTONIC stops across
S3, so suspended-in-a-bag time is excluded; uptimed's own totals use
CLOCK_BOOTTIME and do count it (~62% of nidhoggr's session wall time as of
2026-10-28), which is why this counter exists alongside it.

State: /var/lib/playtime/state.json   {total, boot_id, mono, started}
Seed:  /etc/playtime-seed             seconds accrued before this counter
                                      existed, declared in Nix

Usage: playtime [show|tick|seconds]
  show     human-readable summary (default)
  tick     fold elapsed awake time into the total (run by playtime-tick.timer)
  seconds  total as a bare integer, for scripting
"""

import json
import os
import sys
import time

STATE_DIR = "/var/lib/playtime"
STATE_FILE = os.path.join(STATE_DIR, "state.json")
SEED_FILE = "/etc/playtime-seed"


def mono():
    """Seconds since boot, excluding time spent suspended."""
    return time.clock_gettime(time.CLOCK_MONOTONIC)


def boottime():
    """Seconds since boot, including time spent suspended."""
    return time.clock_gettime(time.CLOCK_BOOTTIME)


def boot_id():
    with open("/proc/sys/kernel/random/boot_id") as f:
        return f.read().strip()


def seed_seconds():
    try:
        with open(SEED_FILE) as f:
            return float(f.read().strip())
    except (OSError, ValueError):
        return 0.0


def load():
    try:
        with open(STATE_FILE) as f:
            state = json.load(f)
    except (OSError, ValueError):
        state = {}
    state.setdefault("total", 0.0)
    state.setdefault("boot_id", "")
    state.setdefault("mono", 0.0)
    state.setdefault("started", time.time())
    return state


def save(state):
    os.makedirs(STATE_DIR, exist_ok=True)
    tmp = STATE_FILE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(state, f)
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, STATE_FILE)
    os.chmod(STATE_FILE, 0o644)


def pending(state, now=None):
    """Awake seconds since the last tick.

    A boot_id mismatch means the last tick was in an earlier boot, so
    everything this session has accrued is still unaccounted for.
    """
    now = mono() if now is None else now
    if state["boot_id"] != boot_id():
        return now
    return max(0.0, now - state["mono"])


def tick():
    state = load()
    now = mono()
    state["total"] += pending(state, now)
    state["boot_id"] = boot_id()
    state["mono"] = now
    save(state)


def fmt(seconds):
    seconds = int(seconds)
    days, rem = divmod(seconds, 86400)
    hours, rem = divmod(rem, 3600)
    return "%3dd %2dh %2dm" % (days, hours, rem // 60)


def show(state, seed, counted):
    total = seed + counted
    since = time.strftime("%Y-%m-%d", time.localtime(state["started"]))
    print("playtime  %s   (%d h)" % (fmt(total), total // 3600))
    print("  seeded  %s   (before this counter existed)" % fmt(seed))
    print("  counted %s   (since %s)" % (fmt(counted), since))
    print("session   %s awake, %s since boot" % (fmt(mono()), fmt(boottime())))


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "show"
    if cmd == "tick":
        tick()
        return 0

    state = load()
    seed = seed_seconds()
    counted = state["total"] + pending(state)

    if cmd == "seconds":
        print(int(seed + counted))
    elif cmd == "show":
        show(state, seed, counted)
    else:
        print("usage: playtime [show|tick|seconds]", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
