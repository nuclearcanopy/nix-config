# dualboot agent prompt

prompt to hand an agent running inside the nixos live usb environment, to perform the
offline ext4 shrink on kuraokami. paste everything inside the fence.

getting it into the live env, in order of convenience: read it from github on a phone;
or mount the root read-only first (`mount -o ro /dev/nvme0n1p2 /mnt && cat
/mnt/home/ankhseraph/nix-config/DUALBOOT_AGENT_PROMPT.md && umount /mnt`) and unmount
before starting.

---

```
You are running inside a NixOS 26.05 graphical live USB environment, as root (or with
passwordless sudo). Your single job is to shrink the ext4 root filesystem on this
machine's internal NVMe drive and create an unformatted partition in the freed space,
for a later Windows install. You are NOT installing Windows and NOT configuring Secure
Boot; stop when the partition exists and the machine boots NixOS again.

## Context

The machine is "kuraokami", a NixOS desktop. Its config lives at ~/nix-config on the
internal disk (repo also on GitHub). The owner wants ~200GB for Windows to play League
of Legends; Vanguard is a kernel anti-cheat that blocks Proton, so a real Windows
install is required. Disk space was already freed ahead of time: the filesystem has
~534GB used of 931GB, so shrinking to 700GB has plenty of headroom.

## Target layout

Internal disk is /dev/nvme0n1, a KINGSTON SA2000M81000G, 1953525168 sectors (931.51 GiB).

  p1  2048        - 1050623     512 MiB   ESP, vfat, /boot        <- DO NOT TOUCH
  p2  1050624     - 1469057023  700 GiB   ext4 root               <- shrink to this
  p3  1469057024  - 1953523711  231 GiB   new, unformatted        <- create this

700 GiB = 1468006400 sectors. p2 end = 1050624 + 1468006400 - 1 = 1469057023.

## Why this is safe (and the one thing that makes it unsafe)

- p2's START SECTOR MUST REMAIN 1050624. Deleting and recreating the partition entry is
  non-destructive ONLY because the recreated entry starts at the identical sector. If
  you recreate it at a different start, all data is lost. Verify this before and after.
- The root filesystem is referenced by FILESYSTEM UUID, not PARTUUID:
  hosts/kuraokami/hardware-configuration.nix uses
  /dev/disk/by-uuid/17c52675-9c32-403f-b556-b37f2a943482. The fs UUID lives inside the
  filesystem, so it survives repartitioning. p2's PARTUUID will change; that is fine.
- The kernel cmdline is `root=fstab`, so the root device is never named on the command
  line. Nothing in the boot path references p2's PARTUUID.

## Hard constraints

- DO NOT write to /dev/sda. That is the live USB you are booted from (Verbatim STORE N
  GO, 28.9 GiB, isohybrid NixOS image). Writing to it destroys your own boot medium.
  Confirm device identity by size and model, not by assuming letters; enumeration can
  differ in the live environment.
- DO NOT mount /dev/nvme0n1p2 while resizing. ext4 cannot shrink mounted; resize2fs
  will refuse. The graphical live session may auto-mount it, so check `findmnt` and
  unmount first.
- DO NOT touch /dev/nvme0n1p1 (the ESP). It is shared with the future Windows install.
- DO NOT run anything from ~/nix-config (no nixos-rebuild, no disko). Running disko
  against this host would destroy the entire disk.
- DO NOT format the new p3. The Windows installer does that itself.

## Procedure

Verify the target first:

  lsblk -o NAME,SIZE,FSTYPE,TYPE,MOUNTPOINT,LABEL,MODEL
  cat /sys/block/nvme0n1/nvme0n1p2/start   # must print 1050624
  blkid /dev/nvme0n1p2                     # must show UUID 17c52675-9c32-403f-b556-b37f2a943482
  findmnt /dev/nvme0n1p2                   # must print nothing; unmount if it does

Then:

  # 1. mandatory fsck; resize2fs refuses to shrink without it
  e2fsck -f /dev/nvme0n1p2

  # 2. shrink the filesystem to 695G, deliberately under the 700G partition target so
  #    step 3 has slack. SLOW: ~2.4M inodes to relocate, expect 30-90 minutes.
  #    Do not interrupt. Do not add a timeout that could kill it.
  resize2fs /dev/nvme0n1p2 695G

  # 3. shrink the partition, same start sector
  sgdisk --delete=2 /dev/nvme0n1
  sgdisk --new=2:1050624:1469057023 --typecode=2:8300 --change-name=2:nixos-root /dev/nvme0n1
  partprobe /dev/nvme0n1

  # 4. grow the fs back out to fill the partition exactly
  e2fsck -f /dev/nvme0n1p2
  resize2fs /dev/nvme0n1p2

  # 5. create the Windows partition in the freed tail, unformatted
  sgdisk --new=3:1469057024:1953523711 --typecode=3:0700 --change-name=3:windows /dev/nvme0n1
  partprobe /dev/nvme0n1

  # 6. verify
  sgdisk -p /dev/nvme0n1
  sgdisk -v /dev/nvme0n1
  e2fsck -fn /dev/nvme0n1p2
  blkid /dev/nvme0n1p2    # UUID must be unchanged

## Failure handling

- If step 2 (resize2fs shrink) fails or is interrupted: DO NOT proceed to step 3. The
  filesystem may be mid-relocation. Re-run `e2fsck -f /dev/nvme0n1p2` and let it repair,
  then re-check the current fs size with `dumpe2fs -h` before deciding anything. The
  partition table is still untouched at that point, so the system is still bootable.
- If step 3 ran but the start sector came out wrong: STOP IMMEDIATELY and do not write
  anything further. Report the exact sgdisk output. Recreating p2 at 1050624 may still
  recover it.
- If e2fsck reports serious corruption at any point, stop and report rather than
  repairing aggressively.
- If resize2fs says the filesystem is already smaller than requested, that means a
  previous run partially succeeded; report the current size instead of guessing.

## When done

Report: the final `sgdisk -p` output, the fs UUID, whether it still matches, and the
final `df -h` for the resized filesystem. Then tell the operator to reboot into NixOS
and confirm it comes up before touching the Windows installer. Do not reboot yourself
without saying so.
```
