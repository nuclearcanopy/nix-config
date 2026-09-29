{ config, lib, inputs, ... }:

let
  allowedUnfree = import ../nix/allowed-unfree.data.nix;

  allowUnfreePredicate = pkg: builtins.elem (inputs.nixpkgs.lib.getName pkg) allowedUnfree;

  mkUnstable = system: import inputs.unstable {
    inherit system;
    config.allowUnfreePredicate = allowUnfreePredicate;
  };

  mkFirefoxPkgs = system: import inputs.nixpkgs-firefox {
    inherit system;
    config.allowUnfreePredicate = allowUnfreePredicate;
  };
in
{
  options.nixos = {
    modules = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.deferredModule;
      default = { };
      description = "Reusable NixOS module buckets. Hosts opt in by reference.";
    };

    configurations = lib.mkOption {
      type = lib.types.lazyAttrsOf (lib.types.submodule {
        options = {
          module = lib.mkOption {
            type = lib.types.deferredModule;
            description = "Root module for this host.";
          };
          username = lib.mkOption {
            type = lib.types.str;
          };
          system = lib.mkOption {
            type = lib.types.str;
            default = "x86_64-linux";
          };
        };
      });
      default = { };
    };
  };

  config.flake.nixosConfigurations = lib.mapAttrs (name: hostCfg:
    inputs.nixpkgs.lib.nixosSystem {
      inherit (hostCfg) system;
      specialArgs = {
        inherit inputs allowedUnfree allowUnfreePredicate;
        inherit (hostCfg) username;
        unstable = mkUnstable hostCfg.system;
        pkgs-firefox = mkFirefoxPkgs hostCfg.system;
      };
      modules = [
        hostCfg.module
        { networking.hostName = lib.mkDefault name; }
      ];
    }
  ) config.nixos.configurations;
}
