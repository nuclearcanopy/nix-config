{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./system.nix
    ../../modules/system
    ../../modules/system/hardware/openrazer.nix
  ];
}
