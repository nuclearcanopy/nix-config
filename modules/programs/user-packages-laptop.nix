{
  # Laptop user packages: subset of the desktop's user-packages.
  # No gaming extras (no bottles, protontricks, vkbasalt, mangohud), no
  # qjackctl (no JACK on the laptop audio bucket).
  homeManager.modules.user-packages-laptop = { pkgs, ... }: {
    home.packages = with pkgs; [
      obs-studio
      audacity
      gimp
      xournalpp
      kdePackages.kdenlive

      libreoffice
      calibre
      lyx
      texliveFull

      signal-desktop
      teams-for-linux
      qbittorrent
      rustdesk-flutter

      picard
      asunder
      feishin
      termsonic
      vlc

      prismlauncher
    ];
  };
}
