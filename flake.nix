{
  description = "NixOS configurations for kuraokami, nidhoggr, and homeserver";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    # pinned to firefox 152.0.3 nixpkgs rev, which is fully cached
    # (current channel wants 152.0.4 which isn't on hydra yet)
    nixpkgs-firefox.url = "github:NixOS/nixpkgs/3d46470bb3030020f7e1361f33514854f5bfa86d";

    # helium browser is not in nixpkgs (ships only as a .deb); pulled from a
    # community flake and injected as pkgs.helium via modules/nix/overlays.nix
    helium = {
      url = "github:amaanq/helium-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      url = "github:nix-community/nixvim/nixos-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs:
    let
      inherit (inputs.nixpkgs) lib;
      moduleFiles = builtins.filter
        (p: let s = toString p; in
          lib.hasSuffix ".nix" s && !lib.hasSuffix ".data.nix" s)
        (lib.filesystem.listFilesRecursive ./modules);
    in
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      imports = moduleFiles;

      perSystem = { system, ... }: {
        packages.disko = inputs.disko.packages.${system}.disko;
      };
    };
}
