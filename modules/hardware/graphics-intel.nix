{
  # Intel UHD 620 iGPU (ThinkPad T480, no discrete GPU).
  # iHD VA-API driver (intel-media-driver) for hardware video decode on Gen 9+.
  # GuC/HuC firmware loaded via i915 kernel params (boot-laptop bucket).
  # intel.updateMicrocode is handled by hardware-configuration.nix.
  nixos.modules.graphics-intel = { pkgs, ... }: {
    hardware.graphics = {
      enable = true;
      enable32Bit = true;

      extraPackages = [
        pkgs.intel-media-driver
        pkgs.pocl
        pkgs.libva
        pkgs.libva-utils
        pkgs.vulkan-loader
        pkgs.intel-gpu-tools
      ];

      extraPackages32 = [
        pkgs.pkgsi686Linux.intel-media-driver
      ];
    };

    environment.variables = {
      LIBVA_DRIVER_NAME = "iHD";
      VDPAU_DRIVER = "va_gl";
    };
  };
}
