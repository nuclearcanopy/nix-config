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

      # libreoffice  # temporarily out: not yet cached for this nixpkgs commit + local build was hitting cc1plus segfaults
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
