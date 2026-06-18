{ inputs, ... }:

{
  nixos.configurations.homeserver = {
    username = "homeserver";
    module = {
      imports = [
        ../../hosts/homeserver/configuration.nix
        inputs.agenix.nixosModules.default
      ];
    };
  };
}
