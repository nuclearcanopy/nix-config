{
  # Boot config for desktop hosts (kuraokami). Kernel choice is left to default
  # NixOS LTS for now; amd_pstate=active is AMD-specific. Hardening kernel params
  # live in the separate hardening bucket.
  nixos.modules.boot-desktop = {
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
