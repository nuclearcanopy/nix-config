{ config, inputs, ... }:

{
  nixos.configurations.homeserver = {
    username = "homeserver";
    module = {
      time.timeZone = inputs.identity.location.timeZone;
      i18n.extraLocaleSettings = inputs.identity.location.extraLocaleSettings;

      imports = [
        ../../hosts/homeserver/hardware-configuration.nix
        inputs.agenix.nixosModules.default

        config.nixos.modules.allow-unfree
        config.nixos.modules.state-version
        config.nixos.modules.server-system
        config.nixos.modules.server-networking
        config.nixos.modules.server-services
        config.nixos.modules.server-watchdog
        config.nixos.modules.server-users
        config.nixos.modules.server-zsh
        config.nixos.modules.secrets
        config.nixos.modules.server-secrets
        config.nixos.modules.server-git
        config.nixos.modules.server-screen-brightness
        config.nixos.modules.nix-gc
      ];
    };
  };
}
