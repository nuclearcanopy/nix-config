{ ... }:

{
  imports = [
    ./secrets.nix
    ./boot.nix
    ./audio.nix
    ./bluetooth.nix
    ./cpu.nix
    ./graphics.nix
    ./network.nix
    ./packages.nix
    ./power.nix
    ../../system/core/nix.nix
    ../../system/desktop/sway.nix
    ../../system/desktop/fonts.nix
    ../../system/desktop/xdg.nix
    ../../system/services/core.nix
    ../../system/services/privacy.nix
  ];
}
