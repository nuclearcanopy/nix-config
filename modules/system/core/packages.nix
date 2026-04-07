{ unstable, pkgs, lib, ... }:

{
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "steam"
    "steam-unwrapped"
    "claude-code"
    "unrar"
  ];

  programs = {
    zsh.enable = true;
    steam = {
      enable = true;
      remotePlay.openFirewall = false;
      dedicatedServer.openFirewall = false;
      localNetworkGameTransfers.openFirewall = false;
    };
    gamemode.enable = true;
  };

  environment.systemPackages = with pkgs; [
    wireguard-tools
    mullvad-vpn
    dnsutils

    bottles
    protonup-qt

    unzip
    zip
    unrar
    p7zip
    wget
    git
    rsync
    usbutils
    pciutils

    cifs-utils

    systemd-manager-tui

    linux-firmware
    ethtool
  ];
}
