{ ... }:

{
  imports = [
    ../../system/network/base.nix
    ../../shared/mullvad-autoconnect.nix
  ];

  # saves ~5.5s on boot; mullvad-autoconnect handles its own nm readiness check
  systemd.services.NetworkManager-wait-online.enable = false;

  systemd.services.mullvad-daemon.serviceConfig.TimeoutStopSec = "5";

  # Laptop: defer autoconnect to graphical.target (after login) instead of the
  # shared default of mullvad-daemon.service. graphical.target intentionally
  # absent from `after`; listing a unit in both wantedBy and after the same
  # target creates a circular ordering that systemd silently drops.
  systemd.services.mullvad-autoconnect = {
    wants    = [ "NetworkManager.service" "mullvad-daemon.service" ];
    wantedBy = [ "graphical.target" ];
  };

  networking = {
    hostName = "nidhoggr";
    networkmanager = {
      wifi.powersave = true;
      wifi.scanRandMacAddress = true;
      wifi.macAddress = "random";
      ethernet.macAddress = "random";
    };
  };
}
