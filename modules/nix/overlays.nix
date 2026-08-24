{
  nixos.modules.overlays = { inputs, ... }: {
    nixpkgs.overlays = [
      inputs.nur.overlays.default
      # helium browser (not in nixpkgs); built by the helium-flake input
      (final: _prev: {
        helium = inputs.helium.packages.${final.stdenv.hostPlatform.system}.default;
      })
    ];
  };
}
