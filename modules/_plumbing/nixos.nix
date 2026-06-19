{ config, lib, inputs, ... }:

let
  allowedUnfree = [
    "steam"
    "steam-original"
    "steam-run"
    "steam-unwrapped"
    "claude-code"
    "unrar"
    "burpsuite"
  ];

  # Identity file lives at /etc/identity.nix on the real
  # filesystem (written by install.sh into /mnt/etc/.../identity.nix at
  # install time). Reading it requires --impure on rebuild/eval commands;
  # nix-commit.zsh sets that automatically. Falls back to "user" if the
  # file is missing (e.g. pure-eval inspection or a fresh clone before
  # install runs).
  identityFile = /etc/identity.nix;
  defaultUsername =
    let check = builtins.tryEval (builtins.pathExists identityFile);
    in if check.success && check.value
       then (import identityFile).username
       else "user";

  mkUnstable = system: import inputs.unstable {
    inherit system;
    config.allowUnfreePredicate =
      pkg: builtins.elem (inputs.nixpkgs.lib.getName pkg) allowedUnfree;
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
            default = defaultUsername;
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
        inherit inputs allowedUnfree;
        inherit (hostCfg) username;
        unstable = mkUnstable hostCfg.system;
      };
      modules = [
        hostCfg.module
        { networking.hostName = lib.mkDefault name; }
      ];
    }
  ) config.nixos.configurations;
}
