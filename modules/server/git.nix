{ pkgs, ... }:

let
  gitconfig = pkgs.writeText "gitconfig" ''
    [user]
      name = homeserver
      email = homeserver@nix-config.git
  '';
in
{
  systemd.tmpfiles.rules = [
    "L+ /home/homeserver/.gitconfig - - - - ${gitconfig}"
  ];
}
