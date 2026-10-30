"""Cumulative powered-on time ("playtime") for this machine.

Counts seconds the machine is actually running. CLOCK_MONOTONIC stops across
S3, so suspended-in-a-bag time is excluded; uptimed's own totals use
CLOCK_BOOTTIME and do count it (~62% of nidhoggr's session wall time as of
2026-10-28), which is why this counter exists alongside it.

State: /var/lib/playtime/state.json   {total, boot_id, mono, started}
Seed:  /etc/playtime-seed             seconds accrued before this counter
                                      existed, declared in Nix

Usage: playtime [show|tick|seconds|waybar]
  show     human-readable summary (default)
  tick     fold elapsed awake time into the total (run by playtime-tick.timer)
  seconds  total as a bare integer, for scripting
  waybar   one-line JSON for a waybar custom module
"""

import json
import os
import shutil
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
        # Nix can only ever write a valid integer here, so reaching this means
        # the file was hand-edited. Say so: silently returning 0 drops the
        # readout by the whole seed (182d on nidhoggr) with no other symptom.
        sys.stderr.write("playtime: ignoring unreadable %s\n" % SEED_FILE)
        return 0.0


def parse_state(path):
    """Load a state dict from `path`, or None if missing or unusable.

    Valid JSON of the wrong shape (`null`, `[]`, a bare number, or a string
    "total") is the dangerous case: it used to survive the OSError/ValueError
    guard and then raise out of setdefault or the `+=`, failing every tick
    forever. save() was never reached, so nothing repaired the file and the
    only symptom was a frozen number on the bar.
    """
    try:
        with open(path) as f:
            obj = json.load(f)
    except (OSError, ValueError):
        return None
    if not isinstance(obj, dict):
        return None
    state = {}
    try:
        state["total"] = float(obj.get("total", 0.0))
        state["mono"] = float(obj.get("mono", 0.0))
        state["started"] = float(obj.get("started", time.time()))
    except (TypeError, ValueError):
        return None
    bid = obj.get("boot_id", "")
    state["boot_id"] = bid if isinstance(bid, str) else ""
    return state


def load():
    """Current state, falling back to the backup copy save() keeps.

    The lifetime total cannot be recomputed from anything on disk, so a lost
    or corrupt primary must not quietly reset it to "seconds since this boot".
    """
    for path in (STATE_FILE, STATE_FILE + ".bak"):
        state = parse_state(path)
        if state is not None:
            return state
    sys.stderr.write("playtime: no usable state, starting from the seed\n")
    return {"total": 0.0, "boot_id": "", "mono": 0.0, "started": time.time()}


def save(state):
    os.makedirs(STATE_DIR, exist_ok=True)
    # Retain the last parseable state so load() has something to fall back on.
    # Guarded by parse_state so a corrupt primary can't overwrite a good copy.
    if parse_state(STATE_FILE) is not None:
        try:
            shutil.copy2(STATE_FILE, STATE_FILE + ".bak")
        except OSError:
            pass
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


def hours(seconds):
    return "{:,} h".format(int(seconds) // 3600)


def show(state, seed, counted):
    total = seed + counted
    since = time.strftime("%Y-%m-%d", time.localtime(state["started"]))
    print("playtime  %s = %8s" % (fmt(total), hours(total)))
    print("  seeded  %s = %8s   (before this counter existed)" % (fmt(seed), hours(seed)))
    print("  counted %s = %8s   (since %s)" % (fmt(counted), hours(counted), since))
    print("session   %s awake, %s since boot" % (fmt(mono()), fmt(boottime())))


def waybar(state, seed, counted):
    total = seed + counted
    print(json.dumps({
        "text": "%dd %dh" % (total // 86400, total % 86400 // 3600),
        "tooltip": "\n".join([
            "playtime  %s = %8s" % (fmt(total), hours(total)),
            "  seeded  %s = %8s" % (fmt(seed), hours(seed)),
            "  counted %s = %8s   since %s" % (
                fmt(counted), hours(counted),
                time.strftime("%Y-%m-%d", time.localtime(state["started"]))),
            "session   %s awake, %s since boot" % (fmt(mono()), fmt(boottime())),
        ]),
    }))


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
    elif cmd == "waybar":
        waybar(state, seed, counted)
    elif cmd == "show":
        show(state, seed, counted)
    else:
        print("usage: playtime [show|tick|seconds|waybar]", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
