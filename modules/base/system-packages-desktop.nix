{
  # Desktop-host system packages and programs. Layered on top of the
  # system-packages-baseline bucket which contributes the cross-host basics.
  nixos.modules.system-packages-desktop = { lib, pkgs, allowedUnfree, ... }: {
    nixpkgs.config.allowUnfreePredicate =
      pkg: builtins.elem (lib.getName pkg) allowedUnfree;

    programs = {
      zsh.enable = true;
      steam = {
        enable = true;
        remotePlay.openFirewall = false;
        dedicatedServer.openFirewall = false;
        localNetworkGameTransfers.openFirewall = false;
      };
      gamemode.enable = true;
    };

    environment.systemPackages = with pkgs; [
      tree
      cifs-utils
      ethtool
    ];
  };
}
