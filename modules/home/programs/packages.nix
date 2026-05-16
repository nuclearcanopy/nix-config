{ pkgs, ... }:

{
  home.packages = with pkgs; [
    obs-studio
    audacity
    gimp
    xournalpp
    kdePackages.kdenlive

    mangohud
    vkbasalt
    protontricks

    bottles
    protonup-qt
    xivlauncher
    prismlauncher

    onlyoffice-desktopeditors
    calibre
    lyx
    texlive.combined.scheme-full

    signal-desktop
    qbittorrent

    bitwarden-desktop

    picard
    asunder
    feishin
    qjackctl
  ];
}
