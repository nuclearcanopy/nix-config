{ config, inputs, ... }:

{
  nixos.configurations.homeserver = {
    username = "homeserver";
    module = {
      imports = [
        ../../hosts/homeserver/hardware-configuration.nix
        inputs.agenix.nixosModules.default

        config.nixos.modules.allow-unfree
        config.nixos.modules.state-version
        config.nixos.modules.server-system
        config.nixos.modules.server-networking
        config.nixos.modules.server-services
        config.nixos.modules.server-users
        config.nixos.modules.server-zsh
        config.nixos.modules.server-secrets
        config.nixos.modules.server-git
        config.nixos.modules.server-screen-brightness
      ];
    };
  };
}
