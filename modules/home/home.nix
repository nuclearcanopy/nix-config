{ ... }:

{
  imports = [
    ../shared/home-base.nix
    ./desktop
    ./shell
    ./programs
    ./dev
  ];
}
