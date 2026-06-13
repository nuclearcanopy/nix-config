{ unstable, pkgs, lib, allowedUnfree, ... }:

{
  imports = [ ../../shared/packages.nix ];

  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) allowedUnfree;

  programs.gamemode.enable = true;

  programs.steam.enable = true;
  programs.zsh.enable = true;

  environment.systemPackages = with pkgs; [
    mullvad-vpn

    brightnessctl
    networkmanagerapplet
    acpi

    xkcdpass

    flashprog  # internal firmware flashing (Libreboot updates)
  ];
}
