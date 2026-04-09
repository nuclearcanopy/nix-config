{ pkgs, ... }:

# AMD Vega iGPU (Ryzen 5500U APU — no discrete GPU).
# Removed from kuraokami: amdgpu.overdrive (no OC), LACT daemon (gpu.nix).
# radv (mesa) is the Vulkan driver — no amdvlk, radv is better for iGPU.
# VA-API via mesa radeonsi gallium driver (saves CPU/battery on video playback).
{
  hardware = {
    cpu.amd.updateMicrocode = true;

    graphics = {
      enable = true;
      enable32Bit = true;

      package = pkgs.mesa;
      package32 = pkgs.pkgsi686Linux.mesa;

      extraPackages = [
        pkgs.vulkan-loader
        pkgs.libva
        pkgs.libva-utils
      ];

    };
  };
}
