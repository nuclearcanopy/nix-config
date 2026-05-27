{ lib, ... }:

{
  imports = [
    ../../system/network/base.nix
    ../../shared/mullvad-autoconnect.nix
  ];

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
  };

  # saves ~5.5s on boot; mullvad-autoconnect handles its own nm readiness check
  systemd.services.NetworkManager-wait-online.enable = false;

  # Cap stop time to prevent hanging shutdown at nss-lookup.target; both services
  # do DNS-touching cleanup that can deadlock after resolved starts unwinding.
  systemd.services.mullvad-daemon.serviceConfig.TimeoutStopSec = "5";
  systemd.services.tailscaled.serviceConfig.TimeoutStopSec = "5";

  # Laptop: start autoconnect as part of graphical.target activation.
  # graphical.target intentionally absent from `after` — listing a unit in both
  # wantedBy and after the same target creates a circular ordering that causes
  # systemd to silently drop the service at boot.
  systemd.services.mullvad-autoconnect = {
    after    = lib.mkForce [ "NetworkManager.service" "mullvad-daemon.service" ];
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
