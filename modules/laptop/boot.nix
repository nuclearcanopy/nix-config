{ pkgs, ... }:

{
  # Zram: compressed RAM swap — critical for 8GB systems
  # Uses ~25% of RAM for ~2x effective capacity
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;  # uses 4GB RAM for ~8GB virtual swap
  };

  boot = {
    loader = {
      systemd-boot.enable = true;
      timeout = 1;
      efi.canTouchEfiVariables = true;
    };

    tmp = {
      useTmpfs = true;
      tmpfsSize = "2G";  # reduced for 8GB RAM
    };

    kernelPackages = pkgs.linuxPackages_zen;

    kernelParams = [
      "pti=on"
      "vsyscall=none"
      "init_on_alloc=1"
      "slab_nomerge"
      "page_alloc.shuffle=1"
      "preempt=full"
      "amd_pstate=active"
      # Laptop display: prevent screen tearing on eDP
      "amdgpu.dc=1"
      # Power saving
      "nmi_watchdog=0"              # disable NMI watchdog (saves power)
      "nowatchdog"                  # disable watchdog timers
      "amdgpu.runpm=1"              # AMD GPU runtime PM
      "amdgpu.dpm=1"                # dynamic power management
      "pcie_aspm=force"             # force PCIe ASPM
      "pcie_aspm.policy=powersupersave"
    ];

    # Kept: network protocol blacklisting for security
    # Removed from kuraokami: uvcvideo (webcam), btusb/bluetooth (BT) — needed on laptop
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

      # Memory efficiency for 8GB RAM
      "vm.swappiness" = 180;              # aggressive zram usage
      "vm.vfs_cache_pressure" = 50;       # keep dentries/inodes longer
      "vm.dirty_ratio" = 10;              # write to disk sooner
      "vm.dirty_background_ratio" = 5;
      "vm.page-cluster" = 0;              # disable swap readahead (zram is fast)

      # Power saving
      "vm.laptop_mode" = 5;               # aggressive disk spin-down
      "kernel.nmi_watchdog" = 0;          # disable NMI watchdog
    };
  };
}
