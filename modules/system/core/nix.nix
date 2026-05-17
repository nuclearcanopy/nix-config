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
      download-buffer-size = 536870912; # 512MB
    };

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 10d";
    };
  };
}
