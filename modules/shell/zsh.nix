{
  homeManager.modules.zsh = { config, ... }: {
    programs.zsh = {
      enable = true;
      dotDir = config.home.homeDirectory;

      enableCompletion = true;
      # compinit only rewrites the dump when it judges it stale, so a dump
      # that stays valid keeps its old mtime, the mh+24 test stays true
      # forever and the full compaudit scan runs on every single start
      # (48ms of a 160ms interactive start, measured). touch resets the
      # window so the cheap -C path actually holds for a day.
      completionInit = ''
        autoload -Uz compinit
        if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then
          compinit
          touch ~/.zcompdump
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
