{ lib, ... }:

{
  options.homeManager.modules = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.deferredModule;
    default = { };
    description = ''
      Reusable home-manager module buckets. Hosts wire them into
      home-manager.users.<username>.imports = [ config.homeManager.modules.x ... ].
      No configurations bridge here because home-manager runs inside the NixOS eval.
    '';
  };
}
