{ lib, ... }:

{
  imports = [
    ../../system/network/base.nix
    ../../shared/mullvad-autoconnect.nix
  ];

  # saves ~5.5s on boot; mullvad-autoconnect handles its own nm readiness check
  systemd.services.NetworkManager-wait-online.enable = false;

  # Laptop: delay VPN connect until graphical session is up
  systemd.services.mullvad-autoconnect = {
    after    = lib.mkForce [ "graphical.target" "NetworkManager.service" "mullvad-daemon.service" ];
    wants    = lib.mkForce [ "NetworkManager.service" "mullvad-daemon.service" ];
    wantedBy = lib.mkForce [ "graphical.target" ];
  };

  networking = {
    hostName = "nidhoggr";
    networkmanager = {
      wifi.powersave = true;
      wifi.scanRandMacAddress = true;
    };
  };
}
