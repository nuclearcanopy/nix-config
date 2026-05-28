{ pkgs, ... }:

{
  hardware = {
    cpu.amd.updateMicrocode = true;

    amdgpu = {
      overdrive = {
        enable = true;
        ppfeaturemask = "0xffffffff";  # enable all overdrive features for LACT
      };
      opencl.enable = true;
    };

    graphics = {
      enable = true;
      enable32Bit = true;

      extraPackages = [
        pkgs.vulkan-loader
      ];
    };
  };
}
