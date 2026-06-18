{
  # Allowlist predicate for unfree packages. The list itself lives in
  # _plumbing/nixos.nix and is threaded in via specialArgs so it's also
  # available to the unstable nixpkgs import.
  nixos.modules.allow-unfree = { lib, allowedUnfree, ... }: {
    nixpkgs.config.allowUnfreePredicate =
      pkg: builtins.elem (lib.getName pkg) allowedUnfree;
  };
}
