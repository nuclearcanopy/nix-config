{
  nixos.modules.overlays = { inputs, ... }: {
    nixpkgs.overlays = [
      inputs.nur.overlays.default
    ];
  };
}
