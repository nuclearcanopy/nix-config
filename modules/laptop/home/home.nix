{ ... }:

{
  imports = [
    ../../shared/home-base.nix
    ./desktop
    # Shell: reuse kuraokami config entirely
    ../../home/shell
    # Programs: pick what makes sense on a laptop, skip gaming/studio
    ../../home/programs/firefox.nix
    ./programs/firefox.nix  # laptop-specific overrides (devPixelsPerPx, battery)
    ../../home/programs/neovim/config.nix
    ../../home/programs/btop.nix
    ../../home/programs/vesktop.nix
    ./programs/packages.nix
    # Dev: reuse kuraokami config entirely
    ../../home/dev
  ];
}
