{
  # Boot config for AMD CPU hosts. amd_pstate=active is the AMD scaling driver;
  # tmpfs sizing and uvcvideo/btusb/intel_sgx blacklist are general kuraokami-flavored
  # choices that happen to live alongside. Hardening kernel params are separate.
  nixos.modules.boot-amd = {
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
  };
}
