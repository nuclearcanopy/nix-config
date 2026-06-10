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
    ./hardening.nix
    ./network.nix
    ./packages.nix
    ./power.nix
    ./trackpad.nix
    ./virtualisation.nix
    ./storage.nix
    ../../system/core/nix.nix
    ../../system/desktop
    ../../system/services
  ];
}
