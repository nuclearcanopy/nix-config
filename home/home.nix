{ config, pkgs, unstable, ... }:

{
  programs.home-manager.enable = true;

  # xdg
  xdg = {
    enable = true;
    mime.enable = true;
  };

  # home
  home = {
    username = "nuclearcanopy";
    homeDirectory = "/home/nuclearcanopy";
    stateVersion = "25.11";

    # fonts only
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      nerd-fonts.noto
      noto-fonts-color-emoji
    ];
  };

  # font config
  fonts.fontconfig = {
    enable = true;
    defaultFonts = {
      monospace = [ "JetBrainsMono Nerd Font" ];
      sansSerif = [ "Noto Sans" ];
      emoji = [ "Noto Color Emoji" ];
    };
  };

  imports = [
    # desktop
    ./desktop/packages.nix
    ./desktop/hyprland.nix
    ./desktop/sway.nix
    ./desktop/hyprpaper.nix
    ./desktop/waybar/config.nix
    ./desktop/mako.nix
    ./desktop/wofi/config.nix
    ./desktop/theme.nix

    # shell
    ./shell/packages.nix
    ./shell/environment.nix
    ./shell/zsh.nix
    ./shell/fish.nix
    ./shell/alacritty.nix

    # programs
    ./programs/packages.nix
    ./programs/neovim/config.nix
    ./programs/btop.nix
    ./programs/fastfetch/config.nix
    ./programs/vesktop.nix
    ./programs/claude-code.nix
    ./programs/steam.nix
    ./programs/asunder.nix
  ];
}
