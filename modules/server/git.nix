{
  # Materialize ~/.gitconfig as a tmpfiles symlink (not declared via
  # home-manager since the server doesn't run home-manager).
  nixos.modules.server-git = { pkgs, username, ... }:

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
        "L+ /home/${username}/.ssh/id_git - - - - /run/agenix/ssh-git"
      ];
    };
}
