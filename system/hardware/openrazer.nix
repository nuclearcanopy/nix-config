{ pkgs, unstable, username, ... }:
{
  hardware.openrazer = {
    enable = true;
    users = [ "${username}" ];
  };

  nixpkgs.overlays = [
    (final: prev: {
      openrazer-daemon = unstable.openrazer-daemon;
    })
  ];

  environment.systemPackages = [
    unstable.polychromatic
  ];
}
