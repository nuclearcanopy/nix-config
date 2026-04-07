{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # creative
    obs-studio
    audacity
    gimp
    xournalpp
    kdePackages.kdenlive

    # gaming
    # requires client argument: _JAVA_AWT_WM_NONREPARENTING=1
    (writeShellScriptBin "bolt-launcher" ''
      exec mullvad-exclude ${bolt-launcher}/bin/bolt-launcher "$@"
    '')
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
    picard               # tagger
    asunder              # ripper
    feishin              # player
    qjackctl
  ];
}
