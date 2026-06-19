{
  # Boot-time optimizations: delay non-critical units off the critical path so
  # the desktop draws faster, then enable scheduling once the user is on it.
  nixos.modules.boot-optimizations = { lib, ... }: {
    # fwupd-refresh fires at OnBootSec=0 by default, burning 2-3s of IO.
    systemd.timers.fwupd-refresh.timerConfig = {
      OnBootSec          = lib.mkForce "10min";
      OnUnitActiveSec    = "1d";
      RandomizedDelaySec = "30min";
    };
    systemd.services.fwupd-refresh.serviceConfig = {
      Nice            = 19;
      IOSchedulingClass = "idle";
    };

    # ananicy takes 1.6s to start; defer to graphical.target.
    systemd.services.ananicy = {
      after    = lib.mkForce [ "graphical.target" ];
      wantedBy = lib.mkForce [ "graphical.target" ];
    };

    # Move docker.socket off the basic.target critical chain; socket activation
    # still works via multi-user.target.
    systemd.sockets.docker.wantedBy = lib.mkForce [ "multi-user.target" ];
  };
}
