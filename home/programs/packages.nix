{ pkgs, unstable, ... }:

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

    # gaming
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
