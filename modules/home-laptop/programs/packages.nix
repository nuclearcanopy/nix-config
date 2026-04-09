{ pkgs, ... }:

{
  home.packages = with pkgs; [
    obs-studio
    audacity
    gimp
    xournalpp
    kdePackages.kdenlive

    onlyoffice-desktopeditors
    calibre
    lyx
    texlive.combined.scheme-full

    signal-desktop
    qbittorrent

    picard
    asunder
    feishin
  ];
}
