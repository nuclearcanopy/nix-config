{
  # Boot-time optimizations: delay non-critical units off the critical path so
  # the desktop draws faster, then enable scheduling once the user is on it.
  nixos.modules.boot-optimizations = { lib, ... }: {
    # The fwupd-refresh timer/service tuning that used to live here went with
    # the fwupd module; see modules/computers/nidhoggr.nix for why.

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
