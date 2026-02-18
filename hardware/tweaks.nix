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
      package = mesa;
      package32 = pkgsi686Linux.mesa;

      # vulkan
      extraPackages = [
        vulkan-loader
        vulkan-tools
      ];
    };
  };
}
