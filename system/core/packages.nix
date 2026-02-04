{ pkgs, lib, ... }:

{
  # unfree
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "steam"
    "steam-unwrapped"
    "claude-code"
  ];

  # programs
  programs = {
    zsh.enable = true;
    steam.enable = true;
  };

  environment.systemPackages = with pkgs; [
    # vpn
    wireguard-tools
    protonvpn-gui

    # gaming
    bottles

    # utilities
    unzip
    wget
    git
    rsync
    usbutils

    # storage
    cifs-utils

    # management
    systemd-manager-tui

    # hardware
    pulseaudio
    linux-firmware
  ];
}
