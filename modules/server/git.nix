{ pkgs, username, ... }:

let
  gitconfig = pkgs.writeText "gitconfig" ''
    [user]
      name = ${username}
      email = ${username}@nix-config.git
  '';
in
{
  systemd.tmpfiles.rules = [
    "L+ /home/${username}/.gitconfig - - - - ${gitconfig}"
  ];
}
