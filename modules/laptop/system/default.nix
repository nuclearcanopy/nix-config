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
    ../../system/desktop
    ../../system/services
  ];
}
