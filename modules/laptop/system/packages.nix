{ unstable, pkgs, lib, allowedUnfree, ... }:

{
  imports = [ ../../shared/packages.nix ];

  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) allowedUnfree;

  programs.steam.enable = true;
  programs.zsh.enable = true;

  environment.systemPackages = with pkgs; [
    mullvad-vpn

    brightnessctl
    networkmanagerapplet
    acpi

    flashprog  # internal firmware flashing (Libreboot updates)
  ];
}
