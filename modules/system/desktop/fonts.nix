{ pkgs, ... }:

{
  fonts = {
    packages = with pkgs; [
      # noto
      nerd-fonts.noto
      noto-fonts
      noto-fonts-color-emoji

      # jetbrains
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
