{ pkgs, ... }:

{
  home.packages = with pkgs; [
    trash-cli
    xdg-utils
    fastfetch
  ];
}
