{
  nixos.modules.earlyoom = {
    # nixpkgs enables systemd-oomd by default. Running it alongside earlyoom
    # means two independent OOM killers with different trigger models (oomd
    # kills cgroups on PSI pressure, earlyoom kills the fattest process on a
    # free-memory threshold), so which one acts first is unpredictable.
    # earlyoom is the one configured here, so oomd goes.
    systemd.oomd.enable = false;

    services.earlyoom = {
      enable = true;
      freeMemThreshold = 5;
      freeSwapThreshold = 10;
      enableNotifications = true;
    };
  };
}
