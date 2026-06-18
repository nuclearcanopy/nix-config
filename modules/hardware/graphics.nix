{
  # AMD microcode + overdrive enablement + 32-bit graphics + vulkan-loader.
  # Pairs with the gpu-amd bucket (LACT) for full AMD GPU control on kuraokami.
  nixos.modules.graphics = { pkgs, ... }: {
    hardware = {
      cpu.amd.updateMicrocode = true;

      amdgpu.overdrive = {
        enable = true;
        ppfeaturemask = "0xffffffff";  # enable all overdrive features for LACT
      };

      graphics = {
        enable = true;
        enable32Bit = true;

        extraPackages = [
          pkgs.vulkan-loader
        ];
      };
    };
  };
}
