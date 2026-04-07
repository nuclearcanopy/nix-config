{ pkgs, unstable, username, ... }:
{
  hardware.openrazer = {
    enable = true;
    users = [ "${username}" ];
  };

  nixpkgs.overlays = [
    (final: prev: {
      openrazer-daemon = unstable.openrazer-daemon;
      # newer kernel module
      linuxPackages_zen = prev.linuxPackages_zen.extend (lpFinal: lpPrev: {
        openrazer = unstable.linuxPackages_zen.openrazer;
      });
    })
  ];

  environment.systemPackages = [
    unstable.polychromatic
  ];
}
