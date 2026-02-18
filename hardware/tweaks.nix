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
      package = pkgs.mesa;
      package32 = pkgs.pkgsi686Linux.mesa;

      # vulkan
      extraPackages = [
        pkgs.vulkan-loader
        pkgs.vulkan-tools
      ];
    };
  };
}
