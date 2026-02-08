{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # browsers
    librewolf
    freetube

    # creative
    obs-studio
    audacity
    gimp
    xournalpp

    # productivity
    onlyoffice-desktopeditors

    # communication
    signal-desktop
    qbittorrent

    # music
    easyeffects          # eq
    picard               # tagger
    asunder              # ripper
    unstable.feishin     # player
  ];
}
