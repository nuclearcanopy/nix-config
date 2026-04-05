{ ... }:

{
  imports = [
    ./zsh/zsh.nix
    ./packages.nix
    ./environment.nix
    ./alacritty.nix
    ./ssh.nix
  ];
}
