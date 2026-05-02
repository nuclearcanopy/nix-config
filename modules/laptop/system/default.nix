{ ... }:

{
  imports = [
    ./secrets.nix
    ./boot.nix
    ./luks.nix
    ./audio.nix
    ./bluetooth.nix
    ./cpu.nix
    ./graphics.nix
    ./network.nix
    ./packages.nix
    ./power.nix
    ./keyboard.nix
    ../../system/core/nix.nix
    ../../system/desktop
    ../../system/services
  ];
}
