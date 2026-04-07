{ pkgs, ... }:

{
  home.packages = with pkgs; [
    yubikey-manager
    bemenu
    j4-dmenu-desktop
    pavucontrol
    mpv
    playerctl
    grim
    slurp
    hyprpicker
    wl-clipboard
    jp2a
    autotiling-rs
  ];
}
