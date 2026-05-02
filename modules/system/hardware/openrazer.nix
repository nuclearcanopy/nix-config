{ pkgs, unstable, username, ... }:
{
  hardware.openrazer = {
    enable = true;
    users = [ username ];
  };

  nixpkgs.overlays = [
    (final: prev: {
      openrazer-daemon = unstable.openrazer-daemon;
      linuxPackages_zen = prev.linuxPackages_zen.extend (_: lpPrev: {
        openrazer = lpPrev.openrazer.overrideAttrs (_: {
          inherit (unstable.openrazer-daemon) version src;
        });
      });
    })
  ];

  environment.systemPackages = [
    unstable.polychromatic
  ];
}
