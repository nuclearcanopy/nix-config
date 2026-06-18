{
  homeManager.modules.user-packages = { pkgs, ... }: {
    home.packages = with pkgs; [
      obs-studio
      audacity
      gimp
      xournalpp
      kdePackages.kdenlive

      mangohud
      vkbasalt
      protontricks

      bottles
      protonup-qt
      xivlauncher
      prismlauncher

      libreoffice
      calibre
      lyx
      texliveFull

      signal-desktop
      qbittorrent

      picard
      asunder
      feishin
      qjackctl
    ];
  };
}
