{ pkgs, unstable, ... }:

{
  home.packages = with pkgs; [
    # browsers
    # firefox - managed by programs.firefox
    freetube

    # creative
    obs-studio
    audacity
    gimp
    xournalpp
    kdePackages.kdenlive

    # gaming
    bolt-launcher  # requires client argument: _JAVA_AWT_WM_NONREPARENTING=1
    mangohud
    vkbasalt
    protontricks
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
    feishin              # player
    qjackctl
  ];
}
