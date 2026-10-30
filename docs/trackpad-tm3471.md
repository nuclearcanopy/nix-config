# trackpad: synaptics tm3471-020 on libreboot t480

aftermarket glass trackpad mod (synaptics tm3471-020, pnp id len2058) installed in a t480 running libreboot. default linux config makes it feel sluggish: initial touch doesn't immediately register, cursor falls behind fast finger movement. the live fix is ps/2 with `rate=200` plus rt-threaded i8042 irqs; rmi4-over-smbus was tried, measured worse on this chip, and declined (see below).

## current state

the live path is **ps/2**, not rmi4. `modules/hardware/trackpad-synaptics.nix`:

```nix
boot.extraModprobeConfig = ''
  options psmouse synaptics_intertouch=0 resetafter=0 rate=200
'';
boot.kernelParams = [ "threadirqs" ];
```

- `synaptics_intertouch=0` pins psmouse to ps/2 and stops it auto-transitioning to rmi4-over-smbus, which regresses to ~63hz on this chip
- `rate=200` selects the chip's high-rate report mode, and is load-bearing on the ps/2 path (it is *not* a holdover; the rmi4 driver would have ignored it)
- `resetafter=0` disables psmouse's periodic chip reset, which caused brief stutters every few seconds
- `threadirqs` plus the `serio-rt` oneshot `chrt -f -p 50`s the `irq/*-i8042` kthreads (keyboard irq 1, aux irq 12) so cursor input never queues behind a busy compositor
- `services.ananicy.extraRules` gives sway `nice = -10`, since sway processes cursor motion on its main thread

steady-state polling is ~100hz only when paired with the smbus-enabled coreboot build (see step 1); without it the chip stays in a base mode and polls ~70hz even with `rate=200`. i2c-i801 init at coreboot time appears to put the chip in a higher-perf internal sampling mode that persists for the session even though linux drives it over ps/2. so the coreboot change is still wanted, just not for the reason it was originally made.

## symptom this fixes

cursor doesn't move for ~100-500ms after touch onset, then jumps tens of pixels. fast swipes drop frames.

## hardware

- chip: synaptics tm3471-020 (board id 3471, fw id 2909640)
- pnp id: len2058; originally lenovo thinkpad e490, same chip used in some aftermarket glass trackpad mods for the t480
- bus options the chip supports: ps/2 (via i8042 controller on serio1) or rmi4 over smbus (via i801 controller, pci 00:1f.4)

stock t480 trackpads are typically tm3289-series with pnp id len2054, which the kernel handles correctly out of the box.

## 1. coreboot: enable the smbus pci device

the skylake soc config (`src/soc/intel/skylake/chipset.cb`) defaults pci 00:1f.4 (smbus) to `off`, and `sklkbl_thinkpad` does not turn it on. in `src/coreboot/default/src/mainboard/lenovo/sklkbl_thinkpad/devicetree.cb`, inside the `device domain 0 on ... end` block:

```
device ref smbus on end
```

build coreboot, flash the rom. tracked in `libreboot-nidhoggr` commit `f3903db`. after reboot:

```
lspci -nn | grep 1f.4
# 00:1f.4 SMBus [0c05]: Intel Corporation Sunrise Point-LP SMBus [8086:9d23]
```

keep this even though rmi4 was declined: it is what gets the chip to ~100hz on the ps/2 path.

## 2. libinput / sway: adaptive accel, dwt off

`modules/gui/sway-host.nix`, nidhoggr block:

```nix
"type:touchpad" = {
  accel_profile = "adaptive";
  pointer_accel = "-0.1";
  natural_scroll = "enabled";
  tap = "disabled";
  dwt = "disabled";
  middle_emulation = "enabled";
};
```

- the match is on `type:touchpad`, deliberately. do **not** substitute a device identifier: on the ps/2 path it is `2:7:SynPS/2_Synaptics_TouchPad`, and sway silently ignores an input rule whose identifier doesn't match, so a wrong string fails with no error at all
- `adaptive` gives velocity scaling; fast swipes amplify, masking the chip's modest peak polling rate
- `dwt = "disabled"` is essential. default `enabled` suppresses touchpad events for ~500ms after every keypress, which on a chip that already has firmware-side onset latency feels like the trackpad is broken
- `pointer_accel = -0.1` and `tap = "disabled"` are taste

## verification

```
$ cat /sys/module/psmouse/parameters/synaptics_intertouch
0

$ grep -A3 'Name="SynPS/2' /proc/bus/input/devices
N: Name="SynPS/2 Synaptics TouchPad"
P: Phys=isa0060/serio1/input0
S: Sysfs=/devices/platform/i8042/serio1/input/input9

$ swaymsg -t get_inputs | grep -A1 Synaptics
"identifier": "2:7:SynPS\/2_Synaptics_TouchPad",
"name": "SynPS\/2 Synaptics TouchPad",
```

the i8042/serio1 sysfs path is the **expected** one. a device on `/devices/pci0000:00/0000:00:1f.4/i2c-6/6-002c/rmi4-00/` means psmouse transitioned to rmi4 and the intertouch parameter did not take.

## declined: rmi4-over-smbus

`psmouse.synaptics_intertouch=1` bypasses the `smbus_pnp_ids[]` passlist check in `drivers/input/mouse/synaptics.c` (len2058 was submitted in a v2 patch reviewed by dmitry torokhov, lore.kernel.org 2025-04, and is still not mainline), forcing the driver to attempt smbus mode. that was the configuration for one day, `9c3d95c` to `fc143b5` (both 2026-06-18), and it was reverted because **rmi4 measured ~63hz on this chip against ~100hz for ps/2 with the smbus coreboot patch in place**.

the earlier writeup concluded "the rmi4 path is unambiguously better". that was wrong for this chip and has been superseded; the `=0` rationale in the module comment is the current one. under `=1` dmesg shows `psmouse serio1: synaptics: Trying to set up SMBus access` followed by `rmi4_f01 rmi4-00.fn01: found RMI device`, and the sway identifier becomes `1739:0:Synaptics_TM3471-020`. hot-reloading psmouse works for testing but leaves the chip in a transitional internal-mode state that adds latency; the mode register only gets one clean init at power-on, so any bus change needs a cold boot.

## other things that didn't work

- **stripping `rate=200` with the chip in rmi4 mode**: no effect, the rmi4 driver ignores the psmouse rate parameter. on the current ps/2 path it does matter
- **`scan_rate` / `polling_req` rmi4 module params**: only exist in the out-of-tree rmi4 driver, not mainline
- **i2c-i801 module params**: only `disable_features` is exposed; no speed knob, smbus locked at standard 100khz
- **libinput quirks (`AttrInputProp` to strip `INPUT_PROP_DIRECT`)**: misdiagnosed for a different device (the t480's separate raydium touchscreen on usb 2386:432f, not the trackpad)

## references

- kernel v2 patch adding len2058 to `smbus_pnp_ids[]` (dmitry torokhov, 2025): [lore.kernel.org thread](https://lore.kernel.org/linux-input/)
- fedora forum thread describing the "skip by tens of pixels" symptom on a related synaptics chip (t14, f34, oct 2021): [ask.fedoraproject.org](https://ask.fedoraproject.org/)
- libreboot-nidhoggr firmware change: commit `f3903db`, "reapply smbus patch: bumps synaptics ps/2 polling to ~100hz"
- coreboot device disable mechanism: `src/soc/intel/skylake/chipset.cb` line 122, `device pci 1f.4 alias smbus off ops smbus_ops end`
