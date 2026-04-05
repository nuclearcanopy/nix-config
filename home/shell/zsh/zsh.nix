{ config, ... }:

{
  programs.zsh = {
    enable = true;

    # plugins
    enableCompletion = true;
    syntaxHighlighting.enable = true;
    autosuggestion.enable = true;

    history = {
      size = 10000;
      save = 10000;
      path = "${config.home.homeDirectory}/.zsh_history";
    };

    # aliases
    shellAliases = {
      snvim = "sudo -E nvim";
      nvfx = "nvim .";
      # NAS mounts automatically via systemd automount - just access /mnt/nas
      sysd-ui = "systemd-manager-tui";
      vpnissue = "mullvad status && mullvad relay list";
      fix-nvim = "rm -f ~/.config/nvim/lazy-lock.json && rm -rf ~/.local/share/nvim/lazy 2>/dev/null || true";
    };

    initContent = ''
      ${builtins.readFile ./prompt.zsh}
      ${builtins.readFile ./nix-commit.zsh}
    '';
  };
}
