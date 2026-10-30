{
  nixos.modules.nix-settings = {
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
    };
    # nix.gc policy lives solely in modules/base/nix-gc.nix (all three hosts
    # import it). It used to be set here too, with an added
    # `--delete-older-than 10d` that silently overrode that module's
    # 5-generation floor; only ~20 generations, all under 3 days old, survived.
  };
}
