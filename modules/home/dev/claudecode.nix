{ pkgs, lib, ... }:
{
  home.sessionVariables = {
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";

    DISABLE_TELEMETRY = "1";
    DISABLE_ERROR_REPORTING = "1";
    DISABLE_BUG_COMMAND = "1";
    CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY = "1";
  };

  programs.claude-code = {
    enable = true;
    package = pkgs.claude-code;
    mcpServers = {
      nixos = {
        type = "stdio";
        command = "mcp-nixos";
      };
    };
    settings = {
      enabledPlugins = {
        "rust-analyzer-lsp@claude-plugins-official" = true;
      };
      attribution = {
        commit = "";
        pr = "";
      };
    };
  };

  home.file.".claude/CLAUDE.md".text = ''
    You are working on a NixOS system. Fixes, changes, patches etc. must ALL be done declaratively or in a Nix-native, reproducible way. Imperative management is discouraged due to how often I reinstall. I use 2-3 devices, always ask me what device I am on before doing something specific. You may also just check if I'm on the laptop, PC or server, but never assume.

    The NixOS configuration lives at ~/nix-config. Always look there for system config, home-manager, flake.nix, module definitions, etc.

    You do NOT have sudo permissions. If a diagnostic or fix requires sudo, stop and ask the user to run that specific command. Do not attempt workarounds or retry the same blocked command in different ways; state the issue clearly and ask.

    For all other commands that don't require sudo, just run them directly; the Claude Code interface already prompts the user for approval when needed. Do not ask permission before running non-privileged commands.

    ## git remotes
    The user maintains all repos on both Codeberg and GitHub simultaneously; they must always be in sync. Whenever you push, push to both. Codeberg is typically named "origin", GitHub is typically named "github". If a repo only has one remote set up, flag it before pushing. URL pattern: ssh://git@codeberg.org/nuclearcanopy/<repo>.git and git@github.com:nuclearcanopy/<repo>.git.

    ## commit messages
    - all lowercase
    - one subject line + one optional body sentence, nothing more
    - purely functional: describe what changed and why, no filler
    - no "this commit", no bullet lists, no markdown in the message

    ## readmes and docs
    - all lowercase
    - minimal: only what someone needs to use the thing
    - no badges, no feature lists, no ai-sounding prose
    - functional over descriptive
  '';

  home.file.".codex/config.toml" = {
    force = true;
    text = ''
      analytics.enabled = false
      history.persistence = "none"
      history.max_bytes = 1048576
      log_dir = "/tmp/codex-log"
      model = "gpt-5.2"
      model_reasoning_effort = "medium"

      [otel]
      exporter = "none"
      metrics_exporter = "none"
      trace_exporter = "none"
      log_user_prompt = false

      [mcp_servers.nixos]
      command = "mcp-nixos"
      args = []

      [notice.model_migrations]
      "gpt-5.2" = "gpt-5.2-codex"
    '';
  };
}
