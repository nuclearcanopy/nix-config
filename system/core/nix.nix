{ ... }:

{
  # disable docs
  documentation.enable = false;

  nix = {
    settings = {
      # flakes
      experimental-features = [ "nix-command" "flakes" ];

      # wheel only
      allowed-users = [ "@wheel" ];

      # auto-optimize
      auto-optimise-store = true;
    };

    # garbage collection
    gc = {
      automatic = true;
      options = "--delete-older-than 10d";
    };

    # store optimization
    optimise.automatic = true;
  };
}
