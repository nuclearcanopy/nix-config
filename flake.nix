{
  description = "Kuraokami NixOS";

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
    # === User Configuration ===
    username = "nuclearcanopy";  # Change this to customize username throughout config
    system = "x86_64-linux";

    unstable-pkgs = import unstable {
      inherit system;
      config.allowUnfree = false;
    };

    # Import secrets (gitignored, requires --impure flag)
    # Must use absolute path because gitignored files don't get copied to nix store
    secrets = import /home/${username}/nix-config/secrets.nix;
  in {
    nixosConfigurations.kuraokami = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { unstable = unstable-pkgs; inherit secrets username; };

      modules = [
	impermanence.nixosModules.impermanence
        ./configuration.nix

        home-manager.nixosModules.home-manager
        {
          home-manager.extraSpecialArgs = { unstable = unstable-pkgs; inherit secrets username; };
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.${username} = import ./home/home.nix;
        }
      ];
    };
  };
}
