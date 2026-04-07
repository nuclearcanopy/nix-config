{ pkgs, ... }:

{
  hardware = {
    cpu.amd.updateMicrocode = true;
    cpu.intel.updateMicrocode = false;

    amdgpu.overdrive.enable = true;

    graphics = {
      enable = true;
      enable32Bit = true;

      package = pkgs.mesa;
      package32 = pkgs.pkgsi686Linux.mesa;

      extraPackages = [
        pkgs.vulkan-loader
        pkgs.vulkan-tools
      ];
    };
  };
}
