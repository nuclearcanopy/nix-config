{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # touchscreen support
    wvkbd              # on-screen keyboard
    libinput-gestures  # touch/touchpad gestures
    wtype              # for gesture actions (typing keys)
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
