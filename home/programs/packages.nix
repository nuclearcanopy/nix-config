{ pkgs, unstable, ... }:

{
  home.packages = with pkgs; [
    # browsers
    librewolf
    # firefox - managed by programs.firefox
    freetube

    # creative
    obs-studio
    audacity
    gimp
    xournalpp
    kdePackages.kdenlive

    # gaming
    bolt-launcher
    mangohud
    vkbasalt
    unstable.protontricks
    xivlauncher

    # productivity
    onlyoffice-desktopeditors
    calibre
    lyx
    texlive.combined.scheme-full

    # communication
    signal-desktop
    qbittorrent

    # music
    easyeffects          # eq
    picard               # tagger
    asunder              # ripper
    unstable.feishin     # player
    qjackctl
  ];
}
