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

        extra-substituters = [ "https://attic.xuyh0120.win/lantian" ];
        extra-trusted-public-keys = [ "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc=" ];
      };

      gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 10d";
      };
    };
  };
}
