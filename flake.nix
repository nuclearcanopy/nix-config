{
  description = "Kuraokami NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, unstable, home-manager, ... }:
  let
    username = "nuclearcanopy";
    system = "x86_64-linux";

    unstable-pkgs = import unstable {
      inherit system;
      config.allowUnfree = false;
    };

    # absolute path - gitignored
    secrets = import /home/${username}/nix-config/secrets.nix;
  in {
    nixosConfigurations.kuraokami = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { unstable = unstable-pkgs; inherit secrets username; };

      modules = [
        ./configuration.nix

        home-manager.nixosModules.home-manager
        {
          home-manager.extraSpecialArgs = { unstable = unstable-pkgs; inherit secrets username; };
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "backup";
          home-manager.users.${username} = import ./home/home.nix;
        }
      ];
    };
  };
}
