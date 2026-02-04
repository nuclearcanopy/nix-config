{ ... }:

{
  # no docs
  documentation.enable = false;

  nix = {
    settings = {
      # flakes
      experimental-features = [ "nix-command" "flakes" ];

      # wheel
      allowed-users = [ "@wheel" ];

      # optimize
      auto-optimise-store = true;
    };

    # gc
    gc = {
      automatic = true;
      options = "--delete-older-than 10d";
    };

    # optimize
    optimise.automatic = true;
  };
}
