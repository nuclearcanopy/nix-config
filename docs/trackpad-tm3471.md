# trackpad: synaptics tm3471-020 on libreboot t480

aftermarket glass trackpad mod (synaptics tm3471-020, pnp id len2058) installed in a t480 running libreboot. default linux config makes it feel sluggish: initial touch doesn't immediately register, cursor falls behind fast finger movement. fix requires changes at three layers: firmware, kernel module parameter, libinput config.

## symptom

cursor doesn't move for ~100-500ms after touch onset, then jumps tens of pixels. fast swipes drop frames. on ps/2 path the chip polls at ~80hz peak and adds noticeable firmware-side filtering delay.

## hardware

- chip: synaptics tm3471-020 (board id 3471, fw id 2909640)
- pnp id: len2058; originally lenovo thinkpad e490, same chip used in some aftermarket glass trackpad mods for the t480
- bus options the chip supports: ps/2 (via i8042 controller on serio1) or rmi4 over smbus (via i801 controller, pci 00:1f.4)

stock t480 trackpads are typically tm3289-series with pnp id len2054, which the kernel handles correctly out of the box. the aftermarket chip needs explicit setup at three layers.

## root cause

two-layer block by default:

1. **coreboot hides the smbus controller.** the skylake soc config (`src/soc/intel/skylake/chipset.cb`) defaults pci 00:1f.4 (smbus) to `off`. without an explicit `on` in the mainboard devicetree.cb, linux can't enumerate the controller and rmi4-over-smbus is unreachable. the `x1_carbon_gen1` mainboard turns it on; `sklkbl_thinkpad` does not.

2. **kernel passlist doesn't include len2058.** the synaptics psmouse driver checks `smbus_pnp_ids[]` in `drivers/input/mouse/synaptics.c` before attempting smbus transition. len2058 was submitted in a v2 patch reviewed by dmitry torokhov (lore.kernel.org, 2025-04) but is not in mainline as of kernel 7.0.11. until it lands, the chip is silently forced to ps/2 mode unless `psmouse.synaptics_intertouch=1` is set explicitly; the article author for the patch noted that bypasses the passlist check.

on ps/2 the chip's own firmware adds ~200-500ms of touch-onset filtering and the host polling rate caps at ~80hz.

## fix

three layers, all required.

### 1. coreboot: enable smbus pci device

in `src/coreboot/default/src/mainboard/lenovo/sklkbl_thinkpad/devicetree.cb`, add inside the `device domain 0 on ... end` block:

```
device ref smbus on end
```

build coreboot, flash the rom. tracked in `libreboot-nidhoggr` commit `f3903db`. after reboot:

```
lspci -nn | grep 1f.4
# 00:1f.4 SMBus [0c05]: Intel Corporation Sunrise Point-LP SMBus [8086:9d23]
```

if 00:1f.4 doesn't appear, the firmware change didn't take effect.

### 2. kernel: bypass the synaptics smbus passlist

`psmouse.synaptics_intertouch=1` forces the driver to attempt smbus mode regardless of pnp passlist membership. in `modules/laptop/system/trackpad.nix`:

```nix
boot.extraModprobeConfig = ''
  options psmouse synaptics_intertouch=1 resetafter=0 rate=200
'';
```

`resetafter=0` disables psmouse's periodic chip reset (otherwise causes brief stutters every few seconds). `rate=200` is a holdover from the ps/2-path tuning; harmless on rmi4 since the rmi4 driver ignores it.

cold reboot. dmesg should show:

```
i801_smbus 0000:00:1f.4: SMBus using PCI interrupt
psmouse serio1: synaptics: Trying to set up SMBus access
rmi4_smbus 6-002c: registering SMbus-connected sensor
rmi4_f01 rmi4-00.fn01: found RMI device, manufacturer: Synaptics, product: TM3471-020
input: Synaptics TM3471-020 as /devices/pci0000:00/0000:00:1f.4/i2c-6/6-002c/rmi4-00/input/inputN
```

hot-reloading psmouse (`modprobe -r psmouse && modprobe psmouse`) works for testing but leaves the chip in a transitional internal-mode state that adds latency. cold boot is required for clean operation; the chip's mode register only gets a single clean init at power-on.

### 3. libinput / sway: adaptive accel, dwt off

in `modules/laptop/home/desktop/sway.nix`:

```nix
"type:touchpad" = {
  accel_profile = "adaptive";
  pointer_accel = "-0.25";
  natural_scroll = "enabled";
  tap = "enabled";
  dwt = "disabled";
  middle_emulation = "enabled";
};
```

- `adaptive` profile gives velocity scaling; fast swipes amplify, masks the chip's modest peak polling rate
- `dwt = "disabled"` is essential. default `dwt = "enabled"` suppresses touchpad events for ~500ms after every keypress, which on a chip that already has firmware-side onset latency feels like the trackpad is broken
- `pointer_accel = -0.25` is taste; positive values feel too fast on this chip

## verification

after reboot, expected state:

```
$ lspci -nn | grep 1f.4
00:1f.4 SMBus [0c05]: Intel Corporation Sunrise Point-LP SMBus [8086:9d23]

$ cat /sys/module/psmouse/parameters/synaptics_intertouch
1

$ grep -B1 "Phys=rmi4" /proc/bus/input/devices | head
N: Name="Synaptics TM3471-020"
P: Phys=rmi4-00/input0

$ swaymsg -t get_inputs | grep -A1 TM3471
"identifier": "1739:0:Synaptics_TM3471-020",
"name": "Synaptics TM3471-020",
```

trackpad's sysfs path should be `/devices/pci0000:00/0000:00:1f.4/i2c-6/6-002c/rmi4-00/input/inputN`, not `/devices/platform/i8042/serio1/`. that path confirms rmi4-over-smbus is in use.

if `synaptics_intertouch=1` is set but the device still shows up as `SynPS/2 Synaptics TouchPad` on `event13`-style i8042 path, the smbus pci device probably isn't exposed; check step 1.

## what didn't work

documented in case it saves someone else the time:

- **stripping ps/2 rate=200 with the chip in rmi4 mode**: no effect, rmi4 driver ignores psmouse rate parameter
- **scan_rate / polling_req rmi4 module params**: only exist in out-of-tree rmi4 driver, not mainline
- **i2c-i801 module params**: only `disable_features` is exposed; no speed knob, smbus locked at standard 100khz
- **libinput quirks (AttrInputProp to strip INPUT_PROP_DIRECT)**: misdiagnosed for a different device (the t480's separate raydium touchscreen on usb 2386:432f, not the trackpad)
- **reverting the smbus coreboot patch and going back to ps/2**: did improve ps/2 polling slightly via a side channel (suspected i801 init affecting the synaptics chip's internal mode), but the rmi4 path is unambiguously better

## references

- kernel v2 patch adding len2058 to `smbus_pnp_ids[]` (dmitry torokhov, 2025): [lore.kernel.org thread](https://lore.kernel.org/linux-input/)
- writeup of the same chip on thinkpad e490 with the kernel patch applied
- fedora forum thread describing the "skip by tens of pixels" symptom on a related synaptics chip (t14, f34, oct 2021): [ask.fedoraproject.org](https://ask.fedoraproject.org/)
- libreboot-nidhoggr firmware change: commit `f3903db`, "reapply smbus patch: bumps synaptics ps/2 polling to ~100hz"
- coreboot device disable mechanism: `src/soc/intel/skylake/chipset.cb` line 122, `device pci 1f.4 alias smbus off ops smbus_ops end`
