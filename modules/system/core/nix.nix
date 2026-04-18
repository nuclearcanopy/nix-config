{ ... }:

{
  documentation = {
    nixos.enable = false;
    doc.enable = false;
  };

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
  };
}
