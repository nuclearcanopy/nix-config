{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # launcher
    bemenu
    j4-dmenu-desktop

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
