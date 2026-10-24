{
  # OpenRazer kernel module + daemon for Razer peripherals (kuraokami).
  # Pinned to unstable for the latest device support; this requires the
  # actual in-use kernel package set (stock linuxPackages here, per
  # boot-amd.nix) to build the matching module version, hence the overlay.
  nixos.modules.openrazer = { lib, pkgs, unstable, username, ... }: {
    hardware.openrazer = {
      enable = true;
      users = [ username ];
    };

    nixpkgs.overlays = [
      (final: prev: {
        openrazer-daemon = unstable.openrazer-daemon;
        linuxPackages = prev.linuxPackages.extend (_: lpPrev: {
          openrazer = lpPrev.openrazer.overrideAttrs (_: {
            inherit (unstable.openrazer-daemon) version src;
          });
        });
      })
    ];

    # sway-session.target, not the module default graphical-session.target:
    # nixos-fake-graphical-session.target pulls the latter up at login
    # before sway runs `systemctl --user import-environment`. mkForce
    # because NixOS's systemd.user.services lists merge by concatenation.
    systemd.user.services.openrazer-daemon = {
      wantedBy = lib.mkForce [ "sway-session.target" ];
      partOf = lib.mkForce [ "sway-session.target" ];
      after = [ "sway-session.target" ];
    };

    environment.systemPackages = [
      unstable.polychromatic
    ];
  };
}
