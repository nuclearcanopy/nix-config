{ pkgs, lib, ... }:

{
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
    enable = true;
    pkcs11.enable = true;
    tctiEnvironment.enable = true;
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
      efi.canTouchEfiVariables = true;
      grub = {
        enable = true;
        device = "nodev";
        efiSupport = true;
      };
    };

    initrd.compressor = "zstd";
    initrd.compressorArgs = [ "-6" "--threads=0" ];

    tmp = {
      useTmpfs = true;
      tmpfsSize = "16G";
    };

    kernelPackages = pkgs.linuxPackages_zen;

    kernelParams = [
      # Security
      "pti=on"
      "vsyscall=none"
      "init_on_alloc=1"
      "slab_nomerge"
      "page_alloc.shuffle=1"
      "preempt=full"
      # Intel
      "intel_pstate=active"
      "i915.enable_fbc=1"           # framebuffer compression — saves power
      "i915.enable_psr=1"           # panel self-refresh — reduces display power
      "i915.enable_guc=3"           # GuC/HuC firmware — better GPU scheduling
      # Power saving
      "nmi_watchdog=0"
      "nowatchdog"
      "workqueue.power_efficient=1"
      "pcie_aspm=force"
      "pcie_aspm.policy=powersupersave"
      "ahci.mobile_lpm_policy=3"
      "snd_hda_intel.power_save=1"
      "snd_hda_intel.power_save_controller=Y"
      # Suspend
      "mem_sleep_default=deep"
    ];

    kernelModules = [ "uvcvideo" ];

    blacklistedKernelModules = [ "dccp" "sctp" "rds" "tipc" ];

    kernel.sysctl = {
      # Network hardening
      "net.ipv4.conf.all.rp_filter" = 2;
      "net.ipv4.conf.default.rp_filter" = 2;
      "net.ipv4.conf.all.accept_redirects" = 0;
      "net.ipv4.conf.default.accept_redirects" = 0;
      "net.ipv6.conf.all.accept_redirects" = 0;
      "net.ipv6.conf.default.accept_redirects" = 0;
      "net.ipv4.conf.all.accept_source_route" = 0;
      "net.ipv4.conf.default.accept_source_route" = 0;
      "net.ipv6.conf.all.accept_source_route" = 0;
      "net.ipv6.conf.default.accept_source_route" = 0;
      "net.ipv4.conf.all.log_martians" = 0;
      "net.ipv4.conf.all.send_redirects" = 0;
      "net.ipv4.conf.default.send_redirects" = 0;
      "fs.protected_symlinks" = 1;
      "fs.protected_hardlinks" = 1;
      "fs.protected_regular" = 2;
      "fs.protected_fifos" = 2;

      # Memory tuning (32GB RAM)
      "vm.swappiness" = 60;                   # zram as overflow safety net; prefer physical RAM
      "vm.vfs_cache_pressure" = 40;           # keep dentries/inodes cached longer
      "vm.dirty_ratio" = 20;                  # batch writes — fewer disk wakeups
      "vm.dirty_background_ratio" = 10;       # batch background writeback
      "vm.page-cluster" = 0;                  # no swap readahead (zram is fast)

      # Power saving
      "vm.laptop_mode" = 5;
      "kernel.nmi_watchdog" = 0;
      "vm.dirty_writeback_centisecs" = 6000;  # 60s writeback interval
      "vm.dirty_expire_centisecs" = 6000;
    };
  };
}
