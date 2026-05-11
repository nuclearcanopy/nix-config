{ pkgs, ... }:

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

  # Cold boot protection: wipe LUKS key from kernel before sleep, re-unlock via TPM2 on resume.
  # ExecStart: luksSuspend flushes I/O and zeroes the in-kernel key while keeping the dm-crypt
  # device node alive (cached pages keep the running system functional through the suspend).
  # ExecStop: runs on sleep.target stop (i.e. after S3 resume). cryptsetup luksResume tries
  # enrolled tokens (TPM2) first; if PCRs shifted, falls back to systemd-ask-password prompt.
  # Note: TPM2 PCR values are preserved across S3 on this platform, so token unlock should work.
  systemd.services.cryptsetup-suspend = {
    description = "Wipe LUKS key before sleep, re-unlock via TPM2 on resume";
    before = [ "sleep.target" ];
    wantedBy = [ "sleep.target" ];
    unitConfig = {
      DefaultDependencies = false;
      StopWhenUnneeded = true;
    };
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.cryptsetup}/bin/cryptsetup luksSuspend cryptroot";
      ExecStop = "${pkgs.cryptsetup}/bin/cryptsetup luksResume cryptroot";
    };
  };

  # TPM2 for LUKS auto-unlock — enroll after first rebuild with:
  #   sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+2+7+12 /dev/<luks-partition>
  security.tpm2 = {
    enable = true;
    pkcs11.enable = true;
    tctiEnvironment.enable = true;
  };

  boot.initrd.systemd.enable = true;

  boot = {
    loader = {
      systemd-boot.enable = true;
      timeout = 1;
      efi.canTouchEfiVariables = true;
    };

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

    blacklistedKernelModules = [
      "dccp" "sctp" "rds" "tipc"
    ];

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
