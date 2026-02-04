{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # browsers
    librewolf
    freetube

    # dev
    claude-code

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
    picard    # tagger
    asunder   # ripper
    feishin   # player

    # files
    pcmanfm
  ];
}
