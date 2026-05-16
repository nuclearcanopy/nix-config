{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./disk.nix
    ./system.nix
    ../../modules/laptop/system
  ];
}
