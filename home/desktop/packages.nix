{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # audio
    pavucontrol
    cava
    bc  # for cava

    # media
    mpv
    playerctl

    # screenshot
    grim
    slurp
    hyprpicker
    wl-clipboard
    jp2a
  ];
}
