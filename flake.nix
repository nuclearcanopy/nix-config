{
  description = "NixOS configurations for kuraokami and homeserver";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
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
      url = "github:nix-community/nixvim/nixos-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, unstable, home-manager, nur, agenix, disko, nixvim, ... }:
  let
    system = "x86_64-linux";

    unstable-pkgs = import unstable {
      inherit system;
      config.allowUnfree = false;
    };
  in {
    packages.${system}.disko = disko.packages.${system}.disko;

    nixosConfigurations = {
      # Desktop workstation
      kuraokami = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          unstable = unstable-pkgs;
          username = "nuclearcanopy";
        };

        modules = [
          ./hosts/kuraokami/configuration.nix

          # nur overlay for firefox extensions
          { nixpkgs.overlays = [ nur.overlays.default ]; }

          # agenix for secrets management
          agenix.nixosModules.default

          home-manager.nixosModules.home-manager
          {
            home-manager.extraSpecialArgs = {
              unstable = unstable-pkgs;
              username = "nuclearcanopy";
            };
            home-manager.sharedModules = [ nixvim.homeModules.nixvim ];
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
            home-manager.users.nuclearcanopy = import ./modules/home/home.nix;
          }
        ];
      };

      # Home server
      homeserver = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          unstable = unstable-pkgs;
        };

        modules = [
          ./hosts/homeserver/configuration.nix

          # agenix for secrets management (for future use)
          agenix.nixosModules.default
        ];
      };
    };
  };
}
