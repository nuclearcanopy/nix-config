{ ... }:

{
  programs.neovim.enable = true;

  home.file.".config/nvim/init.lua".source = ./init.lua;

  # Fix permissions on lazy.nvim files that may have been created by root
  # This removes root-owned files and lets lazy.nvim recreate them with proper permissions
  home.activation.fixNvimPermissions = ''
    $DRY_RUN_CMD sudo rm -f ~/.config/nvim/lazy-lock.json
    $DRY_RUN_CMD sudo chown -R $USER:users ~/.local/share/nvim 2>/dev/null || true
  '';
}

