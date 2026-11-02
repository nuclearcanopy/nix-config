{
  homeManager.modules.claudecode = { pkgs, lib, ... }:

    let
      sessionStartContext = pkgs.writeShellScript "claude-session-start-context" ''
        set -u
        proj="''${CLAUDE_PROJECT_DIR:-$PWD}"
        cd "$proj" 2>/dev/null || exit 0
        if ${pkgs.git}/bin/git rev-parse --git-dir > /dev/null 2>&1; then
          printf '## recent commits\n'
          ${pkgs.git}/bin/git log --oneline -5 2>/dev/null
          printf '\n## uncommitted changes\n'
          ${pkgs.git}/bin/git status -s 2>/dev/null | head -15
          printf '\n## current branch\n'
          ${pkgs.git}/bin/git branch --show-current 2>/dev/null
        fi
        printf '\n## files modified in last 24h\n'
        ${pkgs.findutils}/bin/find . -type f -mtime -1 \
          -not -path './.git/*' -not -path './result*' \
          2>/dev/null | head -10
      '';

      jsonFormat = pkgs.formats.json { };
      agentInstructions = import ./agent-instructions.data.nix;
      agentInstructionsFile = pkgs.writeText "agent-instructions.md" agentInstructions;

      # Second account's config dir (CLAUDE_CONFIG_DIR), kept at parity with
      # ~/.claude for settings/hooks/CLAUDE.md. Credentials/session history
      # stay separate per-dir, which is the point: `claude-alt` logs in as a
      # different account (e.g. a higher-tier sub for overnight runs) while
      # `claude` keeps the primary login. First use of `claude-alt` still
      # needs one interactive `/login`; OAuth can't be seeded declaratively.
      altConfigDir = ".claude-alt";

      claudeSettings = {
        enabledPlugins = {
          "rust-analyzer-lsp@claude-plugins-official" = true;
        };
        attribution = {
          commit = "";
          pr = "";
        };
        permissions.allow = [
          "Bash(nix flake check)"
          "Bash(nix flake check *)"
          "Bash(nix-instantiate --parse *)"
          "Bash(journalctl *)"
          "Bash(hostnamectl)"
          "Bash(hostnamectl --static)"
          "Bash(hostnamectl hostname)"
          "Bash(swaymsg -t get_tree)"
          "Bash(swaymsg -t get_outputs)"
          "Bash(swaymsg -t get_workspaces)"
          "Bash(swaymsg -t get_version)"
          "Bash(ping *)"
          "Bash(dmesg)"
        ];
        hooks = {
          SessionStart = [{
            hooks = [{
              type = "command";
              command = "${sessionStartContext}";
            }];
          }];
        };
      };
    in
    {
      home.sessionVariables = {
        CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
        DO_NOT_TRACK = "1";
        DISABLE_TELEMETRY = "1";
        DISABLE_ERROR_REPORTING = "1";
        DISABLE_BUG_COMMAND = "1";
        CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY = "1";
      };

      programs.zsh.shellAliases.claude-rc =
        "env -u CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC -u DISABLE_TELEMETRY -u DISABLE_GROWTHBOOK claude";
      programs.zsh.shellAliases.claude-alt = ''CLAUDE_CONFIG_DIR="$HOME/${altConfigDir}" claude'';

      programs.claude-code = {
        enable = true;
        package = pkgs.claude-code;
        settings = claudeSettings;
      };

      home.file.".claude/CLAUDE.md".source = agentInstructionsFile;
      home.file."${altConfigDir}/settings.json".source = jsonFormat.generate "claude-alt-settings.json" (
        claudeSettings
        // {
          "$schema" = "https://json.schemastore.org/claude-code-settings.json";
        }
      );
      home.file."${altConfigDir}/CLAUDE.md".source = agentInstructionsFile;
    };
}
