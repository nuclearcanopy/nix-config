{ config, pkgs, unstable, username, ... }:

{
  programs.home-manager.enable = true;

  # keyring (protonvpn & element require it)
  services.gnome-keyring.enable = true;

  # xdg
  xdg = {
    enable = true;
    mime.enable = true;
  };

  # home
  home = {
    username = username;
    homeDirectory = "/home/${username}";
    stateVersion = "25.11";

    # fonts only
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      nerd-fonts.noto
      noto-fonts-color-emoji
    ];

    sessionVariables = {
      _JAVA_AWT_WM_NONREPARENTING = "1"; # bolt launcher fix
    };
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
    ./desktop/sway.nix
    ./desktop/waybar/config.nix
    ./desktop/mako.nix
    ./desktop/theme.nix

    # shell
    ./shell/zsh/zsh.nix
    ./shell/packages.nix
    ./shell/environment.nix
    ./shell/alacritty.nix

    # programs
    ./programs/packages.nix
    ./programs/neovim/config.nix
    ./programs/btop.nix
    ./programs/vesktop.nix
    ./programs/steam.nix
    ./programs/asunder.nix
    ./programs/easyeffects.nix
    ./programs/vkbasalt.nix

    # development
    ./dev/packages.nix
    ./dev/claudecode.nix
  ];
}
