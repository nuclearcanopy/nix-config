{ ... }:

{
  imports = [ ../../modules/shared/host-base.nix ];

  system.stateVersion = "25.11";

  virtualisation.docker = {
    enable = true;
    enableOnBoot = false; # socket-activated; starts on demand
  };
}
