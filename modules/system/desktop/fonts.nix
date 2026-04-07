{ pkgs, ... }:

{
  fonts = {
    packages = with pkgs; [
      nerd-fonts.noto
      noto-fonts
      noto-fonts-color-emoji

      jetbrains-mono
      nerd-fonts.jetbrains-mono
    ];

    fontconfig = {
      enable = true;
      defaultFonts = {
        monospace = [ "JetBrainsMono Nerd Font" ];
        sansSerif = [ "Noto Sans" ];
      };
    };
  };
}
