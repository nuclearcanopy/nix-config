{
  # Laptop user packages: subset of the desktop's user-packages, via the
  # shared user-packages-common.data.nix list.
  # No qjackctl (no JACK on the laptop audio bucket).
  #
  # Deliberately absent, trimmed 2026-09-06 for closure size: kdenlive,
  # texliveFull, teams-for-linux, rustdesk-flutter, feishin, mangohud.
  # Consequences: termsonic is the only Subsonic client here, and lyx has no
  # TeX distribution behind it, so it will not typeset. Do not set
  # EnableMangoHud=true in a Prism instance.cfg on this host; the binary the
  # option shells out to is gone.
  homeManager.modules.user-packages-laptop = { pkgs, ... }: {
    home.packages = (import ./user-packages-common.data.nix pkgs) ++ (with pkgs; [
      calibre
      termsonic
      vlc

      # Minecraft. Prism ships wayland GLFW + gamemode.lib in its wrapper by
      # default; the actual perf switches (EnableFeralGamemode /
      # UseNativeGLFW) live per-instance. jdks order puts 21 (LTS) ahead of
      # 25 so Prism's AutomaticJava picks the LTS on any MC version that
      # accepts both.
      (prismlauncher.override { jdks = [ jdk21 jdk25 jdk17 jdk8 ]; })
    ]);
  };
}
