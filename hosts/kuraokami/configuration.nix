{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./system.nix
    ../../modules/system
  ];
}
