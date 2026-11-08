{
  nixos.modules.fonts = { pkgs, ... }: {
    fonts = {
      packages = with pkgs; [
        nerd-fonts.noto
        noto-fonts
        noto-fonts-color-emoji

        jetbrains-mono
        nerd-fonts.jetbrains-mono

        corefonts # microsoft core fonts incl. times new roman, for libreoffice
      ];

      fontconfig = {
        enable = true;
        defaultFonts = {
          monospace = [ "JetBrainsMono Nerd Font" ];
          sansSerif = [ "Noto Sans" ];
        };
      };
    };
  };
}
