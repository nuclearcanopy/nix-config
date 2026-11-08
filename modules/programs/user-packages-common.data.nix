# Packages shared between kuraokami (user-packages.nix) and nidhoggr
# (user-packages-laptop.nix). Host-specific extras/trims stay in each file;
# see user-packages-laptop.nix's header comment for what's deliberately gone.
pkgs: with pkgs; [
  obs-studio
  audacity
  gimp
  xournalpp

  libreoffice

  signal-desktop
  qbittorrent

  picard
  asunder

  # stremio-linux-shell is NOT listed here: modules/base/home-base.nix ships a
  # `stremio` wrapper (mullvad-exclude + FFMPEG_BIN/FFPROBE_BIN) plus its own
  # com.stremio.Stremio desktop entry, and listing the raw package here too
  # would collide on the binary name.
]
