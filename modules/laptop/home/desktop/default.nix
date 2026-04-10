{ ... }:

{
  imports = [
    # Reuse from kuraokami: general desktop packages, notifications, theming
    ../../../home/desktop/packages.nix
    ../../../home/desktop/mako.nix
    ../../../home/desktop/theme.nix
    # Laptop-specific overrides
    ./sway.nix
    ./waybar/config.nix
    ./swayidle.nix  # auto screen blank + suspend for battery
  ];
}
