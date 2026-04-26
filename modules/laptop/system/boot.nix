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

  boot = {
    loader = {
      systemd-boot.enable = true;
      timeout = 1;
      efi.canTouchEfiVariables = true;
    };

    tmp = {
      useTmpfs = true;
      tmpfsSize = "4G";
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
      # AMD
      "amd_pstate=active"
      "amdgpu.dc=1"
      "amdgpu.abmlevel=4"
      "amdgpu.runpm=1"
      "amdgpu.dpm=1"
      "amdgpu.ppfeaturemask=0xffffffff"
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

      # Memory tuning (16GB RAM)
      "vm.swappiness" = 180;                  # aggressive zram usage — keeps file cache warm
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
