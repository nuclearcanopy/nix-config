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

  stremio-linux-shell
]
