{ pkgs, unstable, ... }:

{
  home.packages = with pkgs; [
    # browsers
    librewolf
    firefox
    freetube

    # creative
    obs-studio
    audacity
    gimp
    xournalpp

    # gaming
    bolt-launcher
    mangohud
    vkbasalt
    unstable.protontricks

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
    qjackctl
  ];
}
