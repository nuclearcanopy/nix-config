{
  homeManager.modules.zsh = { config, ... }: {
    programs.zsh = {
      enable = true;
      dotDir = config.home.homeDirectory;

      enableCompletion = true;
      completionInit = ''
        autoload -Uz compinit
        if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then
          compinit
        else
          compinit -C
        fi
      '';
      syntaxHighlighting.enable = true;
      autosuggestion.enable = true;

      history = {
        size = 10000;
        save = 10000;
        ignoreSpace = true;
      };

      shellAliases = {
        nvfx = "nvim .";
        sysd-ui = "systemd-manager-tui";
        vpnissue = "mullvad status && mullvad relay list";
        fix-nvim = "rm -f ~/.config/nvim/lazy-lock.json && rm -rf ~/.local/share/nvim/lazy 2>/dev/null || true";
      };

      initContent = ''
        ${builtins.readFile ./zsh/prompt.zsh}
        ${builtins.readFile ./zsh/privilege.zsh}
        ${builtins.readFile ./zsh/nix-commit.zsh}
      '';
    };
  };
}
