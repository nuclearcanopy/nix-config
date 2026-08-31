{
  # Boot config for nidhoggr (T480, Libreboot via Deguard). Bootloader is
  # GRUB written to /boot/grub/grub.cfg, read by the Libreboot GRUB payload.
  # EFI support kept as contingency until Libreboot is confirmed stable.
  # Intel-specific kernel params (pstate, i915 flags, ACPI quirks) and
  # 32GB-RAM-tuned sysctl live here too.
  nixos.modules.boot-t480 = { pkgs, ... }: {
    boot = {
      initrd.systemd.enable = true;

      # Cut the "Stop job for Rule-based device manager" delay at initrd→root.
      initrd.systemd.services."systemd-udevd".serviceConfig.TimeoutStopSec = "1";

      loader = {
        systemd-boot.enable = false;
        timeout = 0;
        efi.canTouchEfiVariables = false;
        grub = {
          enable = true;
          device = "/dev/nvme0n1";
          efiSupport = false;
          # ESP is 512M; each kernel+initrd is ~63M so >7 generations brings
          # /boot to ~100% and the next rebuild fails to install bootloader.
          configurationLimit = 7;
          # Switch to text mode before kernel handoff so the initrd LUKS
          # prompt renders cleanly. gfxpayload=keep passes the coreboot FB
          # to the kernel; i915 in initrd clears it before the prompt.
          # timeout_style=hidden suppresses the menu flash with timeout=0.
          extraConfig = "set gfxpayload=keep\nset timeout_style=hidden";
        };
      };

      # i915 in initrd: takes over the coreboot framebuffer early, clearing
      # the Libreboot deer graphic before the LUKS password prompt appears.
      initrd.kernelModules = [ "i915" ];

      initrd.compressor = "zstd";
      initrd.compressorArgs = [ "-6" "--threads=0" ];

      tmp = {
        useTmpfs = true;
        tmpfsSize = "16G";
      };

      kernelPackages = pkgs.linuxPackages;

      kernelParams = [
        # Intel
        "intel_pstate=active"
        # FBC + PSR re-enabled 2026-08-22 to reclaim iGPU idle power (PSR alone
        # is worth ~0.3-1W on a static screen). Both were disabled years ago for
        # scroll stutter that i915 has since fixed. Rollback if Firefox/Chromium
        # scroll stutter or panel flicker returns: set either/both back to 0.
        "i915.enable_fbc=1"
        "i915.enable_psr=1"
        "i915.enable_guc=2"           # HuC-only; Kaby Lake has no GuC submission (kernel warns at boot with =3)
        # Perf-for-security tradeoff: i5-8350U (Coffee Lake) mitigates Retbleed
        # via software IBRS; branch-predictor flush on every kernel entry costs
        # ~10-25% on JS/branch-heavy code. Meltdown (pti), Spectre v1, MDS,
        # TSX-AA, MMIO stale data, SRBDS all remain mitigated.
        "retbleed=off"
        # T480 has no physical serial ports but the kernel enumerates 4
        # phantom ttyS[0-3] from ISA/PNP and blocks udev ~15s per device.
        "8250.nr_uarts=0"
        # Power saving
        "nmi_watchdog=0"
        "nowatchdog"
        "pcie_aspm.policy=default"    # don't force ASPM; Libreboot ACPI tables incomplete
        # If the AX210 falls off the PCIe bus (all-0xff MMIO reads after a
        # failed S3 resume), tear it down and rescan instead of spinning on a
        # dead device. iwlwifi has no error_detected AER callback, so without
        # this the kernel cannot recover the card and any task in its ifup
        # path (NetworkManager, `iw`) blocks forever holding RTNL, taking
        # shutdown with it. Recovery path only; no effect when healthy.
        "iwlwifi.remove_when_gone=1"
        "intel_idle.max_cstate=7"    # cap at C7s; prevents C8/C9/C10 VR switching noise (coil whine). unrelated to i915/suspend.
        # 2026-08-21: external monitors are out of the picture, so the two
        # multi-display i915 EBUSY workarounds that were parked here
        # ("i915.enable_dc=0" and "pcie_port_pm=off") were removed to reclaim
        # awake-idle battery. Both only ever mattered under external-display +
        # heavy GPU load. Rollback if the "Atomic commit failed: Device or
        # resource busy" loop ever returns: re-add both lines.
        # ThinkPad ACPI
        "thinkpad_acpi.force_load=1"  # force-load on non-whitelisted firmware (Libreboot)
        "thinkpad_acpi.fan_control=1" # allow software fan control via /proc/acpi/ibm/fan
        # Suspend: S3 (deep), not s2idle. s2idle on this box never reaches deep
        # package idle (kept warm, ~8-10%/h drain with the lid shut); S3 self-
        # refreshes RAM and drops the SoC to ~0.5W. S3 resumes were previously
        # seen to corrupt i915 display state after 4-6 cycles (permanent modeset
        # EBUSY, needs reboot); accepted for the battery win now that no external
        # display is attached. Rollback: "mem_sleep_default=s2idle".
        "mem_sleep_default=deep"
        # Transient: flashrom -p internal needs userspace /dev/mem access to
        # the PCH SPI controller. Uncomment before reflashing, re-comment after.
        # "iomem=relaxed"
      ];

      kernelModules = [ "uvcvideo" ];

      kernel.sysctl = {
        # Memory tuning (32GB RAM)
        "vm.swappiness" = 120;                  # zram swap is RAM-speed + compressed, so lean on it (range extends past 100)
        "vm.vfs_cache_pressure" = 10;            # keep dentries/inodes cached longer
        "vm.watermark_scale_factor" = 125;       # larger kswapd headroom (~400MB)
        "vm.dirty_ratio" = 20;                  # batch writes; fewer disk wakeups
        "vm.dirty_background_ratio" = 10;
        "vm.page-cluster" = 0;                  # no swap readahead (zram is fast)

        # Power saving
        "vm.laptop_mode" = 5;
        "vm.dirty_writeback_centisecs" = 6000;  # 60s writeback interval
        "vm.dirty_expire_centisecs" = 6000;
      };
    };

    systemd.services.ModemManager.enable = false;

    # Disable OBEX (BT file transfer). Masks the session-bus service so it
    # never activates, and drops obex-data-server blueman pulls in.
    systemd.services.obex.enable = false;
    systemd.user.services.obex.enable = false;
  };
}
