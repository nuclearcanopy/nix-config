#!/usr/bin/env python3
"""Block until N physical keydown events arrive, or a timeout elapses.

Reads raw evdev nodes directly. sway's "input type:keyboard events
disabled" only stops the compositor forwarding events to clients; the
kernel keeps emitting them on the device node, so this still sees keydowns
on a keyboard the caller has told sway to ignore.
"""
import select
import sys
import time

import evdev
from evdev import ecodes


def keyboards():
    devices = []
    for path in evdev.list_devices():
        try:
            dev = evdev.InputDevice(path)
        except OSError:
            continue
        caps = dev.capabilities().get(ecodes.EV_KEY, [])
        if ecodes.KEY_A in caps:
            devices.append(dev)
    return devices


def main():
    target = int(sys.argv[1]) if len(sys.argv) > 1 else 3
    timeout = float(sys.argv[2]) if len(sys.argv) > 2 else 1800
    deadline = time.monotonic() + timeout

    devices = keyboards()
    if not devices:
        return
    by_fd = {d.fd: d for d in devices}

    seen = 0
    while seen < target:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            return
        ready, _, _ = select.select(list(by_fd), [], [], remaining)
        for fd in ready:
            try:
                for event in by_fd[fd].read():
                    if event.type == ecodes.EV_KEY and event.value == 1:
                        seen += 1
                        if seen >= target:
                            return
            except OSError:
                continue


if __name__ == "__main__":
    main()
