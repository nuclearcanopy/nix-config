{ ... }:

{
  imports = [
    ./system.nix
    ./networking.nix
    ./services.nix
    ./users.nix
    ./zsh.nix
    ./secrets.nix
  ];
}
