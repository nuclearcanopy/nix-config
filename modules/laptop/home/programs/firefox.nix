{ lib, ... }:

{
  # Override devPixelsPerPx for laptop display
  programs.firefox.profiles.default.settings = {
    "layout.css.devPixelsPerPx" = lib.mkForce "1.35";
  };
}
