{ ... }:

{
  programs.neovim.enable = true;

  home.file.".config/nvim/init.lua".source = ./init.lua;
}

