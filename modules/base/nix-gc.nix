{
  # Generation retention: always keep the 5 most recent NixOS system
  # generations no matter their age. The weekly nix-gc.service only
  # reclaims store space for whatever this prune already dropped below
  # that floor; it never deletes generations by age itself, so the
  # floor can't be eaten by `--delete-older-than`-style age checks.
  #
  # This is the single owner of nix.gc on all three hosts. nix-settings.nix
  # used to set it too, with an added `--delete-older-than 10d` that quietly
  # defeated the floor above (only ~20 generations survived, none older than
  # three days). Don't reintroduce `options` here or there.
  nixos.modules.nix-gc = { pkgs, ... }: {
    nix.gc = {
      automatic = true;
      dates = "weekly";
    };

    systemd.services.nix-gc-prune-generations = {
      description = "Prune NixOS system generations, keeping the 5 most recent";
      before = [ "nix-gc.service" ];
      wantedBy = [ "nix-gc.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.nix}/bin/nix-env -p /nix/var/nix/profiles/system --delete-generations +5";
      };
    };
  };
}
