{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./system.nix
    ../../modules/laptop/system
    ../../modules/system/hardware/openrazer.nix
  ];
}
