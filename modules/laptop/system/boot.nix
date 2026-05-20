{ pkgs, lib, ... }:

{
  imports = [ ../../shared/hardening.nix ];

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;   # ceiling only; actual usage depends on swap pressure
  };

  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;
    freeSwapThreshold = 10;
    enableNotifications = true;
  };

  services.displayManager = {
    ly = {
      enable = true;
      settings = {
        animate = false;
      };
    };
    defaultSession = "sway";
  };

  # TPM2 for LUKS auto-unlock.
  # After Libreboot: PCR 0 (firmware) changed, PCR 7 (Secure Boot) gone.
  # Existing enrollment is invalidated — you'll get a password prompt.
  # Re-enroll once Libreboot is stable:
  #   sudo systemd-cryptenroll --wipe-slot=tpm2 /dev/nvme0n1p2
  #   sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0 /dev/nvme0n1p2
  # Only PCR 0 — no Secure Boot with Libreboot, so PCR 7 is useless.
  security.tpm2 = {
    enable = false;
    pkcs11.enable = false;
    tctiEnvironment.enable = false;
  };

  boot.initrd.systemd.enable = true;

  # Cut the "Stop job for Rule-based device manager" delay at initrd→root handoff.
  # systemd-udevd in the initrd lingers a few seconds by default; cap it at 1s.
  boot.initrd.systemd.services."systemd-udevd".serviceConfig.TimeoutStopSec = "1";

  # Not used on this laptop.
  services.flatpak.enable = lib.mkForce false;
  systemd.services.ModemManager.enable = false;

  # Disable OBEX (BT file transfer). Masks the session-bus service so it
  # never activates, and drops the obex-data-server blueman pulls in.
  systemd.services.obex.enable = false;
  systemd.user.services.obex.enable = false;

  # ── Boot time optimisations ──────────────────────────────────────────────────

  # fwupd-refresh fires at OnBootSec=0 by default, burning 2-3 s of IO at
  # boot. Delay it and make it low-priority.
  systemd.timers.fwupd-refresh.timerConfig = {
    OnBootSec          = lib.mkForce "10min";
    OnUnitActiveSec    = "1d";
    RandomizedDelaySec = "30min";
  };
  systemd.services.fwupd-refresh.serviceConfig = {
    Nice            = 19;
    IOSchedulingClass = "idle";
  };

  # ananicy takes 1.6 s to start and competes with critical-path services.
  # Delay it to after the graphical session is up — users get snappy scheduling
  # once the desktop is drawn, which is what matters.
  systemd.services.ananicy = {
    after    = lib.mkForce [ "graphical.target" ];
    wantedBy = lib.mkForce [ "graphical.target" ];
  };

  # docker.socket sits in sockets.target → basic.target → critical chain.
  # Moving it to multi-user.target keeps socket-activation intact.
  systemd.sockets.docker.wantedBy = lib.mkForce [ "multi-user.target" ];

  boot = {
    # Libreboot (T480 via Deguard): firmware GRUB payload reads
    # /boot/grub/grub.cfg from the ESP. NixOS GRUB writes that file.
    # EFI support kept as contingency — if Libreboot flash fails, the
    # original UEFI firmware can still boot the EFI GRUB binary on the ESP.
    # After confirming Libreboot works:
    #   - set efi.canTouchEfiVariables = false
    #   - optionally drop efiSupport = true
    loader = {
      systemd-boot.enable = false;
      timeout = 0;
      efi.canTouchEfiVariables = false;
      grub = {
        enable = true;
        device = "/dev/nvme0n1";
        efiSupport = false;
        # Switch to text mode before handing off to kernel so the
        # initrd LUKS prompt renders as clean text, not a broken framebuffer.
        # timeout_style=hidden suppresses the menu flash even with timeout=0.
        # gfxpayload=keep: coreboot has no VGA BIOS so "text" is a no-op and
        # leaves the deer framebuffer active. "keep" passes the coreboot FB to
        # the kernel; i915 in initrd then takes it over and clears it before
        # the LUKS prompt appears.
        extraConfig = "set gfxpayload=keep\nset timeout_style=hidden";
      };
    };

    # i915 in initrd: takes over the coreboot framebuffer early (before the
    # LUKS password prompt), clearing the Libreboot deer graphic and making
    # the password prompt visible.
    initrd.kernelModules = [ "i915" ];

    initrd.compressor = "zstd";
    initrd.compressorArgs = [ "-6" "--threads=0" ];

    tmp = {
      useTmpfs = true;
      tmpfsSize = "16G";
    };

    kernelPackages = pkgs.linuxPackages_latest;

    kernelParams = [
      # Intel
      "intel_pstate=active"
      "i915.enable_fbc=1"           # framebuffer compression — saves power
      "i915.enable_psr=0"           # PSR disabled — causes display stutter with Libreboot ACPI tables
      "i915.enable_guc=3"           # GuC/HuC firmware — better GPU scheduling
      # Power saving
      "nmi_watchdog=0"
      "nowatchdog"
      "workqueue.power_efficient=1"
      "pcie_aspm.policy=default"    # don't force ASPM — Libreboot ACPI tables don't fully describe capabilities
      "intel_idle.max_cstate=7"    # cap at C7s — prevents C8/C9/C10 VR switching noise (coil whine)
      "i915.enable_dc=1"           # limit GPU display C-states — less aggressive power gating, reduces coil whine
      # ThinkPad ACPI
      "thinkpad_acpi.force_load=1"  # force-load on non-whitelisted firmware (Libreboot)
      "thinkpad_acpi.fan_control=1" # allow software fan control via /proc/acpi/ibm/fan
      # Suspend
      "mem_sleep_default=deep"
    ];

    kernelModules = [ "uvcvideo" ];

    kernel.sysctl = {
      # Memory tuning (32GB RAM)
      "vm.swappiness" = 10;                   # 32GB RAM — only swap under real pressure
      "vm.vfs_cache_pressure" = 40;           # keep dentries/inodes cached longer
      "vm.dirty_ratio" = 20;                  # batch writes — fewer disk wakeups
      "vm.dirty_background_ratio" = 10;       # batch background writeback
      "vm.page-cluster" = 0;                  # no swap readahead (zram is fast)

      # Power saving
      "vm.laptop_mode" = 5;
      "vm.dirty_writeback_centisecs" = 6000;  # 60s writeback interval
      "vm.dirty_expire_centisecs" = 6000;
    };
  };
}
