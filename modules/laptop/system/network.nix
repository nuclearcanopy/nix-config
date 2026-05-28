{ lib, pkgs, ... }:

{
  imports = [
    ../../system/network/base.nix
    ../../shared/mullvad-autoconnect.nix
  ];

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
    extraUpFlags  = [ "--accept-dns=false" "--accept-routes=true" ];
    extraSetFlags = [ "--accept-dns=false" "--accept-routes=true" "--exit-node=" ];
  };


  # Tailscale sets default-route=yes on tailscale0 via D-Bus even with --accept-dns=false.
  # This triple-flushes resolved's cache. With strict DNSSEC, each flush re-validates
  # the full chain from root, overwhelming resolved and killing the stub listener.
  # allow-downgrade skips validation on timeout instead of hanging.
  services.resolved.dnssec = lib.mkForce "allow-downgrade";

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
    after    = lib.mkForce [ "NetworkManager.service" "mullvad-daemon.service" "tailscaled-set.service" ];
    wants    = lib.mkForce [ "NetworkManager.service" "mullvad-daemon.service" ];
    wantedBy = lib.mkForce [ "graphical.target" ];
    # Exclude tailscaled from the Mullvad tunnel so Tailscale can reach its control
    # plane directly. Without this, Tailscale can't connect (DNS broken inside VPN),
    # retries SetDefaultRoute repeatedly, and resolved never recovers.
    serviceConfig.ExecStartPost = pkgs.writeShellScript "mullvad-split-tunnel-tailscale" ''
      PID=$(${pkgs.systemd}/bin/systemctl show tailscaled.service --property=MainPID --value)
      [ -n "$PID" ] && [ "$PID" != "0" ] && \
        ${pkgs.mullvad}/bin/mullvad split-tunnel add "$PID" || true
      # Use Mullvad's public ad+malware DNS instead of the tunnel-only 100.64.0.7.
      # If wg0-mullvad drops when Tailscale connects, 194.242.2.4 is still reachable
      # via WiFi, so Mullvad can reconnect instead of deadlocking on DNS.
      ${pkgs.mullvad}/bin/mullvad dns set custom 194.242.2.4 || true
    '';
  };

  networking = {
    hostName = "nidhoggr";
    networkmanager = {
      wifi.powersave = true;
      wifi.scanRandMacAddress = true;
    };
  };
}
