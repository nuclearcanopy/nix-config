{ unstable, pkgs, lib, ... }:

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
    steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
    };
  };

  environment.systemPackages = with pkgs; [
    # vpn
    wireguard-tools
    mullvad-vpn

    # gaming
    bottles

    # utilities
    unzip
    wget
    git
    rsync
    usbutils
    pciutils

    # storage
    cifs-utils

    # management
    systemd-manager-tui

    # hardware
    pulseaudio
    linux-firmware
    ethtool
  ];
}
