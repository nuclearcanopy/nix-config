# power (nidhoggr)

forensic detail for power/suspend history that's too long to keep inline. see the pointer comments in `modules/power/power-suspend.nix`, `modules/power/tlp.nix`, and `modules/boot/boot-t480.nix` for where each section applies.

## ax210 resume-from-s3 failures

on roughly 1 in 10 s3 resumes the ax210 (`0000:01:00.0`) came back inaccessible: mmio reads all-`0xff`, aer logged `uncorrectable (fatal), type=inaccessible`, then `can't recover (no error_detected callback)`.

**trigger confirmed as an iommu fault, not a link-state failure.** every captured occurrence logged in this order: `pm: suspend exit` → `dmar: [dma read no_pasid] request device [01:00.0] fault addr 0x... [fault reason 0x06] pte read access is not set` → the aer fatal. the card replays a dma read on resume against an address whose iommu mapping was not restored; `iommu.strict=1` hard-faults it and the device drops off the bus. iwlwifi registers no `error_detected` aer callback, so the kernel cannot reset it; `wlp1s0` disappears and `nmcli dev wifi list` stays empty until reboot. seen 2026-09-09 13:51 and 2026-09-11 11:46 (~1 in 19 suspends).

on the 2026-08-22 occurrence, networkmanager was mid-`ifup` (`do_setlink` → `ieee80211_open` → `drv_start` → `iwl_poll_bits_mask`) and spun there holding **rtnl** plus the iwlmvm mutex. a task spinning in kernel context can't be signalled, so `systemctl stop networkmanager` never completed, `tlp-sleep`'s `iw` blocked on rtnl too, and shutdown wedged into a force power-off.

three mitigations, escalating:

1. **`RUNTIME_PM_DRIVER_DENYLIST = "thunderbolt xhci_hcd iwlwifi"`** (`modules/power/tlp.nix`). iwlwifi joined 2026-08-22, same D3cold-then-fail-to-resume class as thunderbolt/xhci_hcd. limits blast radius (no rtnl wedge) but doesn't recover the card on its own. verified on the 2026-09-11 recurrence: `remove_when_gone` never fired (card stayed present-but-dead) yet rtnl did not wedge, so the denylist earns its keep.
2. **modprobe unload/reload around s3** (`modules/power/power-suspend.nix`). `powerDownCommands` runs `modprobe -r iwlmvm iwlwifi` before suspend so the driver releases its dma mappings cleanly and has nothing stale to replay; `resumeCommands` reloads it, gated on `/run/iwlwifi-sleep-unloaded` so a partial unload still gets repaired. skipped while wlan rfkill is blocked (systemd-rfkill is masked on this host; a reload would come back soft-unblocked and silently undo the waybar airgap toggle).
3. **`pcie_port_pm=off`** (`modules/boot/boot-t480.nix` kernelparams). added 2026-08-22, dropped when external displays left the picture (reclaiming awake-idle battery), **re-added 2026-09-29**: a ~17.5h s3 sleep recurred with wlan rfkill confirmed unblocked at suspend time (mitigation 2 genuinely ran, no stale mapping possible) yet the card still came back dead — `dmar` fault reason `0x05` (pte write access not set) on the reload's first probe, then aer fatal/inaccessible, "skip fw error dump since bus is dead". that proves the root port itself (`0000:00:1c.0`) sometimes fails to restore the device across s3 independent of what the driver did beforehand. measured zero aer events with `pcie_port_pm=off` vs 12 without, in the original 2026-08-22 test.

mitigation 2 stays in place alongside mitigation 3 (still worth doing for the cases that are a stale-mapping replay, not a root-port failure). needs a reboot to take effect since it's a kernel param. watch for further recurrences over several overnight sleeps before considering this closed.

## battery threshold drift and the udev boot race

battery health thresholds (bat0 20/50, bat1 20/80) are set via tlp's thinkpad plugin + natacpi, working after smbios `product_name` was fixed to `"thinkpad t480"` in the libreboot config (tlp 1.8+ checks `product_name` as a libreboot fallback when `product_version` lacks "thinkpad").

**boot-time race**: the packaged `85-tlp.rules` only reapplies thresholds on `action=="change"` for power_supply devices. if `tlp.service`'s boot-time `tlp init start` races acpi battery enumeration and loses, nothing retries until a later charge-state change fires, letting a pack charge past its cap before the threshold ever takes hold. fixed by mirroring the rule for `action=="add"` too (`modules/power/tlp.nix`), so the very first battery uevent after boot also gets a threshold-apply attempt.

**observed drift, 2026-09-25**: `tlp.service` logged `"setting battery charge thresholds...done"` at boot but bat0's sysfs threshold still read the stale 96/100 until `tlp start` was re-run manually the next day. root cause confirmed 2026-09-28 via a raw ec ram read (`ec_sys` debugfs, offset `0xb0-0xb3`): the configured 20/50/20/80 was correctly written into the h8 chip, so the acpi/ec write path itself was not at fault. thinkpad ec thresholds only gate the *next* charge cycle and won't discharge an already-full pack back down to the cap, which is what let bat0 sit at 100% once it won the race against the udev rule fix landing.

bat0 (internal, ~24wh li-poly) is capped tighter than bat1 (removable power bridge, ~80wh li-ion) — 50 vs 80 — since bat0 is never the pack meant to be pulled for hot-swap, so there's no reason to hold it higher than the minimum useful reserve. it was previously unmanaged and rode the ec default of 96/100, holding it at ~100% permanently next to a cpu that idles in the 60s c, the worst case for calendar ageing. charge order is always bat0 first, then bat1.
