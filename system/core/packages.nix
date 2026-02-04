{ pkgs, lib, ... }:

{
  # unfree allowlist
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

    # network storage
    cifs-utils

    # system management
    systemd-manager-tui

    # hardware
    pulseaudio
    linux-firmware
  ];
}
