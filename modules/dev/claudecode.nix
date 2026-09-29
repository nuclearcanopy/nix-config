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
    in
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
        # mcp-nixos is commented out of modules/dev/dev-packages.nix (pulls
        # cfn-lint whose tests fail upstream); re-add this block once that
        # package is restored, or the binary won't exist.
        # mcpServers.nixos = {
        #   type = "stdio";
        #   command = "mcp-nixos";
        # };
        settings = {
          enabledPlugins = {
            "rust-analyzer-lsp@claude-plugins-official" = true;
          };
          attribution = {
            commit = "";
            pr = "";
          };
          hooks = {
            SessionStart = [{
              hooks = [{
                type = "command";
                command = "${sessionStartContext}";
              }];
            }];
          };
        };
      };

      home.file.".claude/CLAUDE.md".text = ''
        You are working on a NixOS system. Fixes, changes, patches etc. must ALL be done declaratively or in a Nix-native, reproducible way. Imperative management is discouraged due to how often I reinstall. I use 2-3 devices, always ask me what device I am on before doing something specific. You may also just check if I'm on the laptop, PC or server, but never assume.

        The NixOS configuration lives at ~/nix-config. Always look there for system config, home-manager, flake.nix, module definitions, etc.

        On kuraokami and nidhoggr you CAN run sudo: `security.sudo` + `SUDO_ASKPASS` (zenity GUI prompt) are configured in `modules/base/host-base.nix`, shared via `desktop-base` to both hosts. Run privileged commands as `sudo -A <command>`; this pops a graphical password dialog on the user's screen for them to authenticate interactively, it is not passwordless/unattended sudo. Diagnose and fix root-requiring issues directly this way instead of punting back to the user. homeserver is headless with no `desktop-base`/askpass wiring, so sudo there still requires asking the user to run the command themselves.

        For all other commands that don't require sudo, just run them directly; the Claude Code interface already prompts the user for approval when needed. Do not ask permission before running non-privileged commands.

        ## git remotes
        GitHub is the only forge; the account is nuclearcanopy and the remote is typically named "github". URL pattern: git@github.com:nuclearcanopy/<repo>.git. If a repo has no remote set up, flag it before pushing.

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

        ## writing
        - NEVER use em dashes (—) anywhere. Not in chat, not in code comments, not in commit messages, not in docs. They are ugly. Semicolons are the superior grammar for the same job (joining related clauses, parenthetical asides). Use `;`, `:`, `.`, `,`, or parens instead. En dashes (–) also out; use hyphens or restructure.
      '';
    };
}
