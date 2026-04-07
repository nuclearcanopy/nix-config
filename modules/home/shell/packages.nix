{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # utilities
    trash-cli
    xdg-utils
    fastfetch
  ];
}
