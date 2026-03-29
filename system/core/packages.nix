{ unstable, pkgs, lib, ... }:

{
  # unfree
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "steam"
    "steam-unwrapped"
    "claude-code"
    "unrar"
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
    # vpn / network
    wireguard-tools
    mullvad-vpn
    dnsutils

    # gaming
    bottles
    protonup-qt
    openrazer

    # utilities
    unzip
    zip
    unrar
    p7zip
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
