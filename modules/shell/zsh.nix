{
  # Drops the `autoload -U compinit && compinit` that programs.zsh writes into
  # /etc/zshrc. It is unguarded and runs on every interactive shell, in front
  # of the completionInit below, so completions were being initialised twice
  # per shell; zprof put the whole 47.8ms of compaudit on this one. fpath setup
  # lives in /etc/zshenv under enableCompletion and is untouched by this.
  # Desktop-only on purpose: the homeserver has no home-manager zsh module, so
  # the global call is the only compinit it gets. See docs/terminal.md.
  nixos.modules.zsh-system = {
    programs.zsh.enableGlobalCompInit = false;
  };

  homeManager.modules.zsh = { config, ... }: {
    programs.zsh = {
      enable = true;
      dotDir = config.home.homeDirectory;

      enableCompletion = true;
      # Run the full compinit (which means compaudit, 48ms of a 140ms
      # interactive start) at most once a day, and compinit -C otherwise.
      # Two traps, both of which this hits: zsh does not glob inside
      # [[ ]], so the widespread `[[ -n ~/.zcompdump(#qN.mh+24) ]]` form
      # tests a non-empty literal string and is a constant true; and
      # compinit leaves a still-valid dump's mtime alone, so the window
      # needs an explicit touch to reset. Testing fresh rather than stale
      # also keeps a missing dump on the full path, where it has to be.
      # See docs/terminal.md.
      completionInit = ''
        autoload -Uz compinit
        _zcompdump_fresh=( ~/.zcompdump(N.mh-24) )
        if (( $#_zcompdump_fresh )); then
          compinit -C
        else
          compinit
          touch ~/.zcompdump
        fi
        unset _zcompdump_fresh
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
