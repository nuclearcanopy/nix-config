{ pkgs, ... }:

{
  imports = [ ../../shared/hardening.nix ];

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

    kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest-x86_64-v3;

    kernelParams = [
      "amd_pstate=active"
    ];

    blacklistedKernelModules = [
      "uvcvideo"
      "btusb" "bluetooth"
      "intel_sgx"
    ];

    extraModprobeConfig = ''
      options snd_usb_audio use_vmalloc=1
    '';
  };
}
