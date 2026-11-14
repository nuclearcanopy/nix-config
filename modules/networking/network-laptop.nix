{
  # Laptop networking on top of networking-base: MAC randomization (wifi +
  # ethernet), wifi power-save, NetworkManager-wait-online disabled for
  # faster boot. Proton VPN's CLI owns VPN activation from the user session.
  nixos.modules.network-laptop = {
    # saves ~5.5s on boot; VPN activation is deferred to the graphical session
    systemd.services.NetworkManager-wait-online.enable = false;

    networking.networkmanager = {
      wifi.powersave = true;
      wifi.scanRandMacAddress = true;
      wifi.macAddress = "random";
      # TEMP: clone old router's WAN MAC to test ISP MAC binding
      ethernet.macAddress = "0C:0E:76:DB:5C:E0";

      # Proton VPN manages its own NetworkManager tunnel profiles and kill
      # switch. No Mullvad dispatcher is installed on this host.
    };

    # iPhone USB tethering: usbmuxd negotiates pairing and brings up the
    # ethernet-over-USB interface that NetworkManager then picks up.
    services.usbmuxd.enable = true;

    # To use a captive portal, intentionally disconnect Proton VPN first; its
    # standard kill switch allows ordinary networking after a manual disconnect.

    # VLC uses libmicrodns for Chromecast discovery; replies arrive as
    # multicast on 5353 which the stateful firewall won't associate with
    # the outbound query.
    networking.firewall.allowedUDPPorts = [ 5353 ];
  };
}
