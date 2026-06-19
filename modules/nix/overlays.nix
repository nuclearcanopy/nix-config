{
  nixos.modules.overlays = { inputs, ... }: {
    nixpkgs.overlays = [
      inputs.cachyos-kernel.overlays.pinned
      inputs.nur.overlays.default
    ];
  };
}
