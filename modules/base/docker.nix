{
  nixos.modules.docker = { lib, ... }: {
    virtualisation.docker.enable = lib.mkDefault true;
  };
}
