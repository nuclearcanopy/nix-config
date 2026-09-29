{
  # Allowlist predicate for unfree packages. Built once in _plumbing/nixos.nix
  # and threaded in via specialArgs so it's also available to the unstable
  # and firefox nixpkgs imports without re-deriving the same lambda.
  nixos.modules.allow-unfree = { allowUnfreePredicate, ... }: {
    nixpkgs.config.allowUnfreePredicate = allowUnfreePredicate;
  };
}
