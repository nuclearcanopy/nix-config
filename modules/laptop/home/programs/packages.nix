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
    texlive.combined.scheme-full

    signal-desktop
    qbittorrent

    bitwarden-desktop

    picard
    asunder
    feishin
  ];
}
