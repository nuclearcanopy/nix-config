{ pkgs, ... }:

{
  hardware = {
    cpu.amd.updateMicrocode = true;
    cpu.intel.updateMicrocode = false;

    amdgpu.overdrive.enable = true;

    graphics = {
      enable = true;
      enable32Bit = true;

      extraPackages = [
        pkgs.vulkan-loader
      ];
    };
  };
}
