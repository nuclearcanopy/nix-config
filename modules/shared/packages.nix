{ pkgs, ... }:

# System packages common to all desktop/laptop hosts.
# Host-specific packages stay in modules/system/core/packages.nix (kuraokami)
# and modules/laptop/system/packages.nix (nidhoggr).
{
  # Sets dumpcap capabilities and creates the wireshark group so non-root
  # users in that group can capture. Membership is in shared/host-base.nix.
  programs.wireshark = {
    enable = true;
    package = pkgs.wireshark; # GUI; default is wireshark-cli
  };

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
