{ inputs, ... }:

{
  nixos.configurations.kuraokami = {
    username = "nuclearcanopy";
    module = { unstable, username, ... }: {
      imports = [
        ../../hosts/kuraokami/configuration.nix
        inputs.agenix.nixosModules.default
        inputs.home-manager.nixosModules.home-manager
      ];

      nixpkgs.overlays = [
        inputs.cachyos-kernel.overlays.pinned
        inputs.nur.overlays.default
      ];

      home-manager = {
        extraSpecialArgs = { inherit unstable username; };
        sharedModules = [ inputs.nixvim.homeModules.nixvim ];
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "backup";
        users.${username} = import ../../modules/home/home.nix;
      };
    };
  };
}
