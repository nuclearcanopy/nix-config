{ ... }:

{
  documentation.enable = false;

  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      allowed-users = [ "@wheel" ];
      auto-optimise-store = true;
    };

    gc = {
      automatic = true;
      options = "--delete-older-than 10d";
    };
 
    optimise.automatic = true;
  };
}
