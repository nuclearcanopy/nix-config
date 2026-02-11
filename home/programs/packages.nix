{ pkgs, unstable, ... }:

{
  home.packages = with pkgs; [
    # browsers
    librewolf
    ungoogled-chromium
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
    element-desktop
    qbittorrent

    # music
    easyeffects          # eq
    picard               # tagger
    asunder              # ripper
    unstable.feishin     # player
  ];
}
