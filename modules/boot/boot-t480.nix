{
  # Boot config for nidhoggr (T480, Libreboot via Deguard). Bootloader is
  # GRUB written to /boot/grub/grub.cfg, read by the Libreboot GRUB payload.
  # EFI support kept as contingency until Libreboot is confirmed stable.
  # Intel-specific kernel params (pstate, i915 flags, ACPI quirks) and
  # 32GB-RAM-tuned sysctl live here too.
  nixos.modules.boot-t480 = { lib, pkgs, ... }: {
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

      kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest-x86_64-v3;

      kernelParams = [
        # Intel
        "intel_pstate=active"
        "i915.enable_fbc=1"           # framebuffer compression; saves power
        "i915.enable_psr=0"           # PSR off; causes display stutter with Libreboot ACPI tables
        "i915.enable_guc=3"           # GuC/HuC firmware; better GPU scheduling
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
        "intel_idle.max_cstate=7"    # cap at C7s; prevents C8/C9/C10 VR switching noise (coil whine)
        "i915.enable_dc=1"           # limit GPU display C-states; reduces coil whine
        # ThinkPad ACPI
        "thinkpad_acpi.force_load=1"  # force-load on non-whitelisted firmware (Libreboot)
        "thinkpad_acpi.fan_control=1" # allow software fan control via /proc/acpi/ibm/fan
        # Suspend
        "mem_sleep_default=deep"
        # Transient: flashrom -p internal needs userspace /dev/mem access to
        # the PCH SPI controller. Uncomment before reflashing, re-comment after.
        # "iomem=relaxed"
      ];

      kernelModules = [ "uvcvideo" ];

      kernel.sysctl = {
        # Memory tuning (32GB RAM)
        "vm.swappiness" = 10;                   # only swap under real pressure
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

    # Not used on this laptop.
    services.flatpak.enable = lib.mkForce false;
    systemd.services.ModemManager.enable = false;

    # Disable OBEX (BT file transfer). Masks the session-bus service so it
    # never activates, and drops obex-data-server blueman pulls in.
    systemd.services.obex.enable = false;
    systemd.user.services.obex.enable = false;
  };
}
