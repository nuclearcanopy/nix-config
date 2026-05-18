{ unstable, pkgs, lib, ... }:

# Removed from kuraokami: steam, gamemode, bottles, protonup-qt.
# Added: brightnessctl (screen brightness), networkmanager-applet (WiFi tray).
{
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "claude-code"
    "unrar"
    "steam"
    "steam-original"
    "steam-run"
    "steam-unwrapped"
  ];

  programs.steam.enable = true;

  programs.zsh.enable = true;

  environment.systemPackages = with pkgs; [
    wireguard-tools
    mullvad-vpn
    dnsutils

    unzip
    zip
    unrar
    p7zip
    wget
    git
    rsync
    usbutils
    pciutils

    systemd-manager-tui

    linux-firmware

    brightnessctl
    networkmanagerapplet
    acpi

    flashprog  # internal firmware flashing (Libreboot updates)
  ];
}
