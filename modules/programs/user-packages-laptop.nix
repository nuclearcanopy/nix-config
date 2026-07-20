{
  # Laptop user packages: subset of the desktop's user-packages.
  # No qjackctl (no JACK on the laptop audio bucket). mangohud kept for
  # per-instance Prism overlay (toggle via Shift_R+F12 by default).
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

      brave

      # Minecraft. Prism ships wayland GLFW + gamemode.lib in its wrapper by
      # default; the actual perf switches (EnableFeralGamemode /
      # EnableMangoHud / UseNativeGLFW) live per-instance. mangohud is added
      # for its overlay binary. jdks order puts 21 (LTS) ahead of 25 so
      # Prism's AutomaticJava picks the LTS on any MC version that accepts
      # both.
      (prismlauncher.override { jdks = [ jdk21 jdk25 jdk17 jdk8 ]; })
      mangohud
    ];
  };
}
