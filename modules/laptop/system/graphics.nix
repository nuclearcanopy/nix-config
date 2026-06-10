{ pkgs, ... }:

# Intel UHD 620 iGPU (ThinkPad T480, no discrete GPU).
# iHD VA-API driver (intel-media-driver) for hardware video decode on Gen 9+.
# GuC/HuC firmware loaded via i915 kernel params in boot.nix.
# intel.updateMicrocode is handled by hardware-configuration.nix.
{
  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;

      extraPackages = [
        pkgs.intel-media-driver   # iHD VA-API (Broadwell / Gen 8+)
        pkgs.pocl                 # CPU OpenCL (NEO 25+ dropped Gen 9/KBL support)
        pkgs.libva
        pkgs.libva-utils
        pkgs.vulkan-loader
        pkgs.intel-gpu-tools      # intel_gpu_top, intel_reg etc.
      ];

      extraPackages32 = [
        pkgs.pkgsi686Linux.intel-media-driver
      ];
    };

    # ThinkPad TrackPoint: middle-button scroll wheel
    trackpoint = {
      enable = true;
      emulateWheel = true;
      sensitivity = 200;
      speed = 97;
    };
  };

  environment.variables = {
    LIBVA_DRIVER_NAME = "iHD";
    VDPAU_DRIVER = "va_gl";       # VDPAU via VA-API (no native Intel VDPAU)
  };
}
