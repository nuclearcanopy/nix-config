{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # fun
    cowsay

    # utilities
    tree
    trash-cli
    xdg-utils

    # dev
    gnumake
    gcc
  ];
}
