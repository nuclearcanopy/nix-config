{
  # nix-ld provides a real dynamic loader at /lib64/ld-linux so
  # prebuilt/generic-linux binaries can run without steam-run's FHS
  # sandbox (which breaks here on the dead /mnt/nas autofs mount).
  #
  # needed for the boomi atom: its install4j installer and the atom
  # service itself both ship a bundled amazon corretto jre that is
  # dynamically linked against a standard glibc + X11 stack. the
  # libraries below cover that jre plus its awt/swing gui deps.
  nixos.modules.nix-ld = { pkgs, ... }: {
    programs.nix-ld = {
      enable = true;
      libraries = with pkgs; [
        stdenv.cc.cc.lib
        zlib
        freetype
        fontconfig
        alsa-lib
        libx11
        libxext
        libxrender
        libxtst
        libxi
        libxt
        libxrandr
        libxinerama
        libxcursor
        libxcb
      ];
    };
  };
}
