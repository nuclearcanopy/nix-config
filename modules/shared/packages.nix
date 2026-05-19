{ pkgs, ... }:

# System packages common to all desktop/laptop hosts.
# Host-specific packages stay in modules/system/core/packages.nix (kuraokami)
# and modules/laptop/system/packages.nix (nidhoggr).
{
  environment.systemPackages = with pkgs; [
    wireguard-tools
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
  ];
}
