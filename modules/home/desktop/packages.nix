{ pkgs, ... }:

{
  home.packages = with pkgs; [
    yubikey-manager

    # launcher
    bemenu
    j4-dmenu-desktop

    # audio
    pavucontrol

    # media
    mpv
    playerctl

    # screenshot
    grim
    slurp
    hyprpicker
    wl-clipboard
    jp2a

    # tiling
    autotiling-rs
  ];
}
