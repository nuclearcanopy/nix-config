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

# Bound on how long select() may block, so a keyboard plugged in after the
# lock started gets picked up and no wait can wedge silently.
RESCAN_SEC = 5.0


def boottime():
    """Seconds since boot, including suspend.

    Not monotonic: the lid can close mid-wait and CLOCK_MONOTONIC stops
    across S3, which would leave the safety timeout with no wall-clock bound.
    """
    return time.clock_gettime(time.CLOCK_BOOTTIME)


def is_keyboard(dev):
    return ecodes.KEY_A in dev.capabilities().get(ecodes.EV_KEY, [])


def main():
    target = int(sys.argv[1]) if len(sys.argv) > 1 else 3
    timeout = float(sys.argv[2]) if len(sys.argv) > 2 else 1800
    deadline = boottime() + timeout

    devs = {}       # path -> InputDevice

    def rescan():
        for path in evdev.list_devices():
            if path in devs:
                continue
            try:
                dev = evdev.InputDevice(path)
            except OSError:
                continue
            if is_keyboard(dev):
                devs[path] = dev
            else:
                dev.close()

    def drop(path):
        dev = devs.pop(path, None)
        if dev is not None:
            try:
                dev.close()
            except OSError:
                pass

    rescan()
    seen = 0
    while seen < target:
        remaining = deadline - boottime()
        if remaining <= 0:
            return
        wait = min(RESCAN_SEC, remaining)

        by_fd = {d.fd: p for p, d in devs.items()}
        if by_fd:
            ready, _, _ = select.select(list(by_fd), [], [], wait)
        else:
            # Nothing to watch. Sleep rather than spin, and keep waiting: the
            # caller has sway's keyboard input disabled and only re-enables it
            # when we exit, so bailing out early would strand the session.
            time.sleep(wait)
            ready = []

        for fd in ready:
            path = by_fd[fd]
            try:
                for event in devs[path].read():
                    if event.type == ecodes.EV_KEY and event.value == 1:
                        seen += 1
                        if seen >= target:
                            return
            except OSError:
                # Unplugged. The node stays readable (EPOLLHUP) while read()
                # keeps raising ENODEV, so leaving it in the set pinned a core
                # for the rest of the timeout, lid shut, on battery.
                drop(path)

        rescan()


if __name__ == "__main__":
    main()
