{ pkgs, unstable, ... }:

{
  hardware = {
    # microcode
    cpu = {
      intel.updateMicrocode = false;
      amd.updateMicrocode = true;
    };

    # overdrive
    amdgpu.overdrive.enable = true;

    # graphics
    graphics = {
      enable = true;
      enable32Bit = true;

      # mesa
      package = unstable.mesa;
      package32 = unstable.pkgsi686Linux.mesa;

      # vulkan
      extraPackages = [
        unstable.vulkan-loader
        pkgs.vulkan-tools
      ];
    };
  };
}
