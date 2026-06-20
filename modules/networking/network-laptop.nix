{
  # Laptop networking on top of networking-base: MAC randomization (wifi +
  # ethernet), wifi power-save, NetworkManager-wait-online disabled for
  # faster boot.
  nixos.modules.network-laptop = {
    # saves ~5.5s on boot; mullvad-autoconnect handles its own nm readiness check
    systemd.services.NetworkManager-wait-online.enable = false;

    systemd.services.mullvad-daemon.serviceConfig.TimeoutStopSec = "5";

    networking.networkmanager = {
      wifi.powersave = true;
      wifi.scanRandMacAddress = true;
      wifi.macAddress = "random";
      ethernet.macAddress = "random";
    };

    # iPhone USB tethering: usbmuxd negotiates pairing and brings up the
    # ethernet-over-USB interface that NetworkManager then picks up.
    services.usbmuxd.enable = true;
  };
}
