{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # browsers
    librewolf

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
    easyeffects # eq
    picard      # tagger
    asunder     # ripper
    feishin     # player
  ];
}
