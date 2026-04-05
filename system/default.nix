{ ... }:

{
  imports = [
    ./secrets.nix
    ./core
    ./desktop
    ./hardware
    ./network
    ./services
  ];
}
