{
  description = "NixOS configurations for kuraokami, nidhoggr, and homeserver";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

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

  outputs = { self, nixpkgs, unstable, home-manager, nur, agenix, disko, nixvim, ... }:
  let
    system = "x86_64-linux";
    username = "nuclearcanopy";

    allowedUnfree = [
      "steam"
      "steam-original"
      "steam-run"
      "steam-unwrapped"
      "claude-code"
      "unrar"
      "wappalyzer"
      "burpsuite"
    ];

    unstable-pkgs = import unstable {
      inherit system;
      config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) allowedUnfree;
    };

    # Shared host builder for desktop/laptop systems with home-manager
    mkHost = { hostConfig, homeModule }: nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {
        unstable = unstable-pkgs;
        inherit username allowedUnfree;
      };

      modules = [
        hostConfig
        {
          nixpkgs.overlays = [
            nur.overlays.default
          ];
        }
        agenix.nixosModules.default
        home-manager.nixosModules.home-manager
        {
          home-manager = {
            extraSpecialArgs = {
              unstable = unstable-pkgs;
              inherit username;
            };
            sharedModules = [ nixvim.homeModules.nixvim ];
            useGlobalPkgs = true;
            useUserPackages = true;
            backupFileExtension = "backup";
            users.${username} = import homeModule;
          };
        }
      ];
    };
  in {
    packages.${system}.disko = disko.packages.${system}.disko;

    nixosConfigurations = {
      kuraokami = mkHost {
        hostConfig = ./hosts/kuraokami/configuration.nix;
        homeModule = ./modules/home/home.nix;
      };

      nidhoggr = mkHost {
        hostConfig = ./hosts/nidhoggr/configuration.nix;
        homeModule = ./modules/laptop/home/home.nix;
      };

      homeserver = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          unstable = unstable-pkgs;
          username = "homeserver";
          inherit allowedUnfree;
        };

        modules = [
          ./hosts/homeserver/configuration.nix
          agenix.nixosModules.default
        ];
      };
    };
  };
}
