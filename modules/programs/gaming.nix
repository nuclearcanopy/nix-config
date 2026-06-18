{
  # Steam + gamemode. Requires the allow-unfree bucket for steam packages
  # to be permitted by nixpkgs.config.allowUnfreePredicate.
  nixos.modules.gaming = {
    programs = {
      steam = {
        enable = true;
        remotePlay.openFirewall = false;
        dedicatedServer.openFirewall = false;
        localNetworkGameTransfers.openFirewall = false;
      };
      gamemode.enable = true;
    };
  };
}
