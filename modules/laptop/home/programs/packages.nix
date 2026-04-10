{ pkgs, ... }:

{
  home.packages = with pkgs; [
    obs-studio
    audacity
    gimp
    xournalpp
    kdePackages.kdenlive

    (writeShellScriptBin "bolt-launcher" ''
      # needs _JAVA_AWT_WM_NONREPARENTING=1
      exec mullvad-exclude ${bolt-launcher}/bin/bolt-launcher "$@"
    '')
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
