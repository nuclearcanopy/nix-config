{
  # Shared home-manager wiring for hosts that use HM. Pulls in the NixOS
  # module, threads unstable+username into HM specialArgs, enables nixvim
  # as a shared module, and sets the common useGlobalPkgs/useUserPackages/
  # backupFileExtension toggles. Hosts add their per-user imports list via
  # `home-manager.users.<username>.imports` separately.
  nixos.modules.home-manager-wiring = { inputs, unstable, username, pkgs-firefox, ... }: {
    imports = [ inputs.home-manager.nixosModules.home-manager ];

    home-manager = {
      extraSpecialArgs = { inherit unstable username pkgs-firefox; };
      sharedModules = [ inputs.nixvim.homeModules.nixvim ];
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "backup";
    };
  };
}
