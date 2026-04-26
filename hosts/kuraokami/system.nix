{ ... }:

{
  imports = [ ../../modules/shared/host-base.nix ];

  system.stateVersion = "25.11";
  networking.hostName = "kuraokami";

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 33;
  };

  virtualisation.docker.enable = true;
}
