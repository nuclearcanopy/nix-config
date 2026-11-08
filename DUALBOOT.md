# dualboot

windows partition on kuraokami for league of legends. vanguard (riot's anti-cheat) runs
in the windows kernel and blocks wine/proton entirely, so a real windows install is the
only option.

## layout

disk is `/dev/nvme0n1`, kingston sa2000m81000g, 1953525168 sectors (931.51 gib).

|  | start | end | size | notes |
|---|---|---|---|---|
| p1 | 2048 | 1050623 | 512 mib | esp, vfat, `/boot`. shared with windows. do not touch |
| p2 | 1050624 | 1469057023 | 700 gib | ext4 root. start sector is load-bearing |
| p3 | 1469057024 | 1953523711 | 231 gib | windows (ntfs, formatted by the windows installer) |

700 gib = 1468006400 sectors; p2 end = 1050624 + 1468006400 - 1.

## why the repartition is safe

- root is referenced by **filesystem** uuid (`/dev/disk/by-uuid/17c52675-...` in
  `hosts/kuraokami/hardware-configuration.nix`), not partuuid. the fs uuid lives inside
  the filesystem, so deleting and recreating the partition entry does not break it.
- kernel cmdline is `root=fstab`: the root device is never named on the command line, it
  is resolved from the initrd's fstab. nothing in the boot path references p2's partuuid.
- consequence: `sgdisk --delete=2` followed by `--new=2:1050624:...` is non-destructive
  **provided the start sector is identical**. only the table is rewritten.

## resize procedure

ext4 cannot shrink while mounted, so this runs from the live usb with the root
filesystem unmounted. the verbatim store n go (`/dev/sda`) already carries a
nixos-graphical-26.05 image; boot it, open a terminal, `sudo -i`.

```bash
# 1. mandatory fsck; resize2fs refuses to shrink without it
e2fsck -f /dev/nvme0n1p2

# 2. shrink the filesystem to 695G, deliberately under the 700G target so step 3
#    has slack. slow: ~2.4M inodes to relocate, 30-90 min. do not interrupt.
resize2fs /dev/nvme0n1p2 695G

# 3. shrink the partition to exactly 700 gib, same start sector
sgdisk --delete=2 /dev/nvme0n1
sgdisk --new=2:1050624:1469057023 --typecode=2:8300 --change-name=2:nixos-root /dev/nvme0n1
partprobe /dev/nvme0n1

# 4. grow the fs back out to fill the partition exactly
e2fsck -f /dev/nvme0n1p2
resize2fs /dev/nvme0n1p2

# 5. create the windows partition in the freed tail
sgdisk --new=3:1469057024:1953523711 --typecode=3:0700 --change-name=3:windows /dev/nvme0n1
partprobe /dev/nvme0n1

# 6. verify, then reboot into nixos and confirm it comes up
sgdisk -p /dev/nvme0n1
e2fsck -fn /dev/nvme0n1p2
```

step 2 is the only irreversible moment; a power loss mid-relocation means a reinstall.

## secure boot (the part that decides whether league runs)

current state:

- tpm 2.0: present, `/dev/tpm0`, version 2. kuraokami does not import
  `modules/boot/tpm2-off.nix` (that is nidhoggr's libreboot workaround), so it is live.
  vanguard enforces tpm 2.0 on every windows version, plus uefi boot mode, gpt, iommu.
- secure boot: **disabled**. firmware is ami 5.17, uefi 2.70.
- nixos boots unsigned systemd-boot, so enabling secure boot stops nixos booting.

**do not use lanzaboote on this host.** vanguard does not merely read the `SecureBoot`
uefi variable, it runs a policy check that requires the secure boot database to be at
**factory defaults** and secure boot mode = **standard**. riot's remediation for
`VAN: STATUS_SB_POLICY` is literally "restore factory keys". lanzaboote enrolls custom
keys and leaves the machine in custom/user mode (`bootctl status` → `enabled (user)`),
which is the state riot tells you to undo. `sbctl enroll-keys --microsoft` keeps windows
bootable but does not restore standard mode. there is no confirmed report of vanguard
accepting a custom-key machine.

it is also not cheaply reversible: returning to a vanguard-compatible state means
restoring factory keys, which wipes the sbctl keys and makes nixos unbootable with
secure boot on. you cannot flip between the two per boot.

separate brick risk on this box specifically: with only a custom cert in `db`, firmware
refuses to execute the rx 7900 xtx's microsoft-signed uefi gop option rom, giving **no
post output at all** (no logo, no firmware setup) until the os driver loads. sbctl
refuses to enroll when it detects option roms unless forced.

**approach instead:** keep factory microsoft keys, no lanzaboote. vanguard's secure boot
check is a per-boot-session runtime check, so toggle secure boot in the firmware: on for
windows, off for nixos. reversible, no signing infrastructure, no brick risk.

the cost is a firmware visit on every os switch. if that becomes intolerable the
alternative is putting windows on a separate physical disk, not custom keys.

## why windows 11 and not 10

windows 10 does still run league: vanguard enforces tpm 2.0 on every windows version,
but secure boot is only a windows 11 requirement (the lol wiki documents the win10
exception; riot's own secure boot guide does not carve it out, so the sources conflict).
chose 11 anyway:

- win10's only advantage was skipping the firmware toggle, and the toggle is accepted
- win10 has been eol since oct 2025, unpatched, on a box exposed to an online game
- riot dropping win10 post-eol is widely expected
- **vanguard on-demand** (since 24 jun 2026) loads the kernel driver only while the game
  is running instead of always-on from boot, but requires win11 25h2+ with secure boot,
  tpm 2.0, iommu, vbs and hvci. win10 cannot use it at all. on-demand is opt-in and vbs
  + hvci cost framerate, so it is a later decision, not a prerequisite.

## firmware settings vanguard requires

- tpm 2.0: present and live
- uefi boot mode + gpt: already the case
- **iommu / amd-vi: check this, it is often off by default on amd boards**
- secure boot: standard mode, factory keys, on for windows / off for nixos

## ordering

1. resize (above), confirm nixos boots
2. install windows 11 into p3 with secure boot still off; the installer checks for
   secure boot *capability*, not that it is enabled
3. enable secure boot and iommu in the firmware, boot windows, install league
4. toggle secure boot off again when booting back into nixos

## disko warning

`scripts/install.sh` runs disko, which **destroys the whole disk including windows**.
there is no preserve mode. `hosts/kuraokami/disko.nix` carries the same warning inline.
