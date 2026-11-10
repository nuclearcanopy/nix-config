{
  # Laptop user packages: subset of the desktop's user-packages, via the
  # shared user-packages-common.data.nix list.
  # No qjackctl (no JACK on the laptop audio bucket).
  #
  # Deliberately absent, trimmed 2026-09-06 for closure size: kdenlive,
  # texliveFull, teams-for-linux, rustdesk-flutter, feishin, mangohud.
  # Consequence: termsonic is the only Subsonic client here. Do not set
  # EnableMangoHud=true in a Prism instance.cfg on this host; the binary the
  # option shells out to is gone. lyx went with texlive on both hosts
  # (2026-10-30); no LaTeX toolchain is installed anywhere now.
  homeManager.modules.user-packages-laptop = { pkgs, ... }: {
    home.packages = (import ./user-packages-common.data.nix pkgs) ++ (with pkgs; [
      calibre
      termsonic
      vlc

      # Proton VPN's CLI has no split tunneling, so Minecraft uses the normal
      # Proton route. Keep Prism's Java selection aligned with kuraokami.
      (prismlauncher.override { jdks = [ jdk21 jdk25 jdk17 jdk8 ]; })
      # Prism still ships wayland GLFW + gamemode.lib in its wrapper by
      # default; the perf switches (EnableFeralGamemode / UseNativeGLFW) live
      # per-instance. Note mangohud is still absent on this host, so do not
      # set EnableMangoHud=true in an instance.cfg here.
    ]);
  };
}
