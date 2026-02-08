{
  description = "Kuroakami NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    impermanence.url = "github:nix-community/impermanence";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, unstable, impermanence, home-manager, ... }:
  let
    system = "x86_64-linux";

    unstable-pkgs = import unstable {
      inherit system;
      config.allowUnfree = false;
    };
  in {
    nixosConfigurations.kuraokami = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { unstable = unstable-pkgs; };

      modules = [
	impermanence.nixosModules.impermanence
        ./configuration.nix

        home-manager.nixosModules.home-manager
        {
          home-manager.extraSpecialArgs = { unstable = unstable-pkgs; };
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.nuclearcanopy = import ./home/home.nix;
        }
      ];
    };
  };
}
