{ pkgs, ... }:

{
  home.packages = with pkgs; [
    obs-studio
    audacity
    gimp
    xournalpp
    kdePackages.kdenlive

    libreoffice
    calibre
    lyx
    texliveFull

    signal-desktop
    qbittorrent

    picard
    asunder
    feishin

    prismlauncher
  ];
}
