{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # launcher
    bemenu
    j4-dmenu-desktop

    # audio
    pavucontrol

    # media
    mpv
    playerctl

    # screenshot
    wayshot
    slurp
    hyprpicker
    wl-clipboard
    jp2a
  ];
}
