{
  # Laptop-specific override of the mullvad-autoconnect trigger: defer to
  # graphical.target (after login) instead of mullvad-daemon.service.
  # graphical.target intentionally absent from `after`; listing a unit in
  # both wantedBy and after the same target creates a circular ordering
  # that systemd silently drops.
  nixos.modules.mullvad-graphical-target = {
    systemd.services.mullvad-autoconnect = {
      wants    = [ "NetworkManager.service" "mullvad-daemon.service" ];
      wantedBy = [ "graphical.target" ];
    };
  };
}
