{ config, username, ... }:

{
  programs.neovim.enable = true;

  home.file.".config/nvim/init.lua".source = config.lib.file.mkOutOfStoreSymlink "/home/${username}/nix-config/home/programs/neovim/init.lua";
}

