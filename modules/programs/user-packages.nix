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
      gamescope

      bottles
      protonup-qt
      xivlauncher
      prismlauncher

      libreoffice
      # calibre     # temporarily out: pulls onnxruntime which fails to build
      lyx
      texliveFull

      brave

      signal-desktop
      qbittorrent

      picard
      asunder
      feishin
      qjackctl
    ];
  };
}
