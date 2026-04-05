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
      "pti=on"
      "vsyscall=none"
      "init_on_alloc=1"
      "slab_nomerge"
      "page_alloc.shuffle=1"
      "amdgpu.ppfeaturemask=0xffffffff"
      "preempt=full"
    ];

    blacklistedKernelModules = [
      "dccp" "sctp" "rds" "tipc"
      "uvcvideo"
      "btusb" "bluetooth"
    ];

    extraModprobeConfig = ''
      options snd_usb_audio use_vmalloc=1
    '';

    kernel.sysctl = {
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
    };
  };
}
