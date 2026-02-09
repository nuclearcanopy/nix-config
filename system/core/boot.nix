{ pkgs, ... }:

{
  boot = {
    loader = {
      systemd-boot.enable = true;
      timeout = 1;
      efi.canTouchEfiVariables = true;
    };

    tmp = {
      useTmpfs = true;
      tmpfsSize = "8G";
    };

    kernelPackages = pkgs.linuxPackages_zen;

    kernelParams = [
      # security
      "pti=on"
      "vsyscall=none"
      "init_on_alloc=1"
      "slab_nomerge"
      "page_alloc.shuffle=1"

      # gpu
      "amdgpu.ppfeaturemask=0xffffffff"
      "preempt=full"
    ];

    blacklistedKernelModules = [
      "dccp" "sctp" "rds" "tipc"
      "uvcvideo"
      "btusb" "bluetooth"
      "r8169"
    ];

    kernelModules = [ "r8168" ];

    extraModprobeConfig = ''
      options snd_usb_audio use_vmalloc=1
      # Fix RTL8111 network drops - disable ASPM and enable MSI
      options r8169 aspm=0 use_dac=1
    ''; 

    kernel.sysctl = {
      # network
      "net.ipv4.conf.all.rp_filter" = 2;
      "net.ipv4.conf.default.rp_filter" = 2;

      "net.ipv4.conf.all.accept_redirects" = 0;
      "net.ipv4.conf.default.accept_redirects" = 0;
      "net.ipv6.conf.all.accept_redirects" = 0;
      "net.ipv6.conf.default.accept_redirects" = 0;

      # filesystem
      "fs.protected_symlinks" = 1;
      "fs.protected_hardlinks" = 1;
      "fs.protected_regular" = 2;
      "fs.protected_fifos" = 2;
    };
  };
}
