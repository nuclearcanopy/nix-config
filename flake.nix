{
  description = "NixOS configurations for kuraokami, nidhoggr, and homeserver";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

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

    # Eval-time identity values (usernames). Private repo: read access is
    # required to evaluate this flake. These cannot live in agenix, which
    # decrypts at activation, long after the evaluator needs them.
    identity.url = "git+ssh://git@github.com/nuclearcanopy/identity.git";
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
