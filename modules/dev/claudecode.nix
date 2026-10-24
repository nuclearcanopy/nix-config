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
        You are working on a NixOS system. Fixes, changes, patches etc. must ALL be done declaratively or in a Nix-native, reproducible way. Imperative management is discouraged due to how often I reinstall.

        I use 2-3 devices (kuraokami desktop, nidhoggr laptop, homeserver). Infer which one from context (hostname, cwd, which host's module is being edited, running processes) and state the inference so it can be corrected; only ask outright when it's genuinely ambiguous.

        The NixOS configuration lives at ~/nix-config. Always look there for system config, home-manager, flake.nix, module definitions, etc.

        ## agents
        Default to spinning up Agent subagents liberally and in parallel; this overrides the tool's own default caution ("don't spawn unless asked"). Don't wait to be asked each time: treat any multi-part ask (an audit, "look into X", a refactor touching several independent files/domains) as implicit permission to split it across subagents rather than working through it serially. Prefer background agents so work overlaps; only run one in the foreground when its result blocks the very next step. Still skip spawning one for a single trivial lookup a direct Read/grep already answers; the point is to multithread real work, not to wrap every tool call in ceremony.

        ## sudo
        On kuraokami and nidhoggr you CAN run sudo: `security.sudo` + `SUDO_ASKPASS` (zenity GUI prompt) are configured in `modules/base/host-base.nix`, shared via `desktop-base` to both hosts. Run privileged commands as `sudo -A <command>` directly, without asking permission first; the zenity prompt itself is the real confirmation gate (it pops a graphical password dialog on the user's screen, it is not passwordless/unattended), so an extra "can I run this" question first is redundant. homeserver is headless with no `desktop-base`/askpass wiring, so sudo there still requires asking the user to run the command themselves.

        Exception: `nixos-rebuild switch` (or `doas` equivalent). Stop once the config evaluates cleanly (`nix flake check` or building `.config.system.build.toplevel`) and leave the actual switch to the user; don't run it yourself even via sudo -A.

        For all other non-privileged commands, just run them directly; the Claude Code interface already prompts for approval when needed.

        ## verification
        Don't run `nix flake check` / eval verification automatically after every edit. Do it when asked, or right before handing something off for the user to build or rebuild.

        ## git workflow
        For my own repos (nix-config and anything else under my account that isn't an upstream contribution): once a change works and matches what I asked for, commit and push by default without asking, the whole flow, not just a local commit. Don't make me say "yes commit and push" every time.

        Ask first instead of auto-committing/pushing when: it's a contribution to someone else's repo (fork/PR workflow, see below, always confirm before pushing/opening a PR there); a check failed (build, eval, tests, lint); or the change touches something security/compromise-sensitive (secrets, auth, exposed services, anything hard to reverse). In those cases, say why, then ask.

        Never add a Claude/AI co-author trailer to commits in my own repos (external contributions follow the AI disclosure rules further down instead).

        Split work into multiple small, progressive commits rather than one big one, each a coherent and independently revertible step (e.g. "fix bug X" separate from "refactor Y" separate from "add feature Z"), even if it all came out of one session. If unrelated pre-existing uncommitted changes are sitting in the tree, commit those as their own step(s) first, don't fold them into a commit describing this session's work.

        ### git remotes
        GitHub is the only forge; the account is nuclearcanopy and the remote is typically named "github". URL pattern: git@github.com:nuclearcanopy/<repo>.git. If a repo has no remote set up, flag it before pushing.

        ### commit messages
        - all lowercase
        - one subject line + one optional body sentence, nothing more
        - dense and technical: pack in the essence, no filler
        - purely functional: describe what changed and why
        - no "this commit", no bullet lists, no markdown in the message

        ### PR/issue descriptions on other people's repos
        Write these like I would, not like an AI assistant. No "Summary"/"Test plan" template headers unless the project's own template requires them. No hedging filler ("happy to", "let me know if", "flagging this explicitly rather than guessing"). State facts and open questions plainly, terse and technical, same density as a commit message. GitHub shows a public, permanent "edited" revision history on issue/PR bodies and comments visible to anyone, not just maintainers, so get the tone right before posting instead of planning to clean it up after.

        Before creating any PR, check for a template and use it instead of writing free-form; don't skip checklist items it has. GitHub looks in, in order: `.github/pull_request_template.md`, `.github/PULL_REQUEST_TEMPLATE.md`, `.github/PULL_REQUEST_TEMPLATE/` (multiple templates), `docs/pull_request_template.md`, and the repo root `pull_request_template.md`. Check all of them (case-insensitive), not just the first guess, before assuming there's none.

        ### AI disclosure on external contributions
        Default to disclosing AI assistance on PRs/issues to other people's repos, even when not required, using this block in the PR/issue body:

        ```markdown
        > [!NOTE]
        > **AI disclosure:** this patch and this description were written with Claude Code (Claude Sonnet 5, `claude-sonnet-5`). I reviewed the diff in full, understand it, and take full responsibility for its correctness.
        ```

        Swap in whichever Claude model is actually running the session. If the project has a formal AI-contribution policy (check CONTRIBUTING.md), follow its required format exactly in addition to this block; e.g. nixpkgs requires an `Assisted-by: <tool>, <model>` git trailer on the commit itself, which this note doesn't replace. If a project bans AI-assisted contributions outright (e.g. Prism Launcher), don't contribute there with my help at all.

        Only check "built"/"tested" boxes or claim something was verified if it was actually run this session, not assumed. If a real build/test attempt fails for reasons unrelated to the change (confirm by isolating the failure, e.g. building the specific unrelated derivation alone), say so explicitly in the PR rather than silently leaving the box unchecked or claiming success.

        ## comments and docs
        Prefer a separate doc over a long inline comment. Comments should be short, roughly 4-5 lines at most, stating the current load-bearing fact, not a multi-paragraph investigation log. Deep forensic detail (incident timelines, root-cause investigations, declined alternatives) belongs in a doc (e.g. a project's `docs/` folder), with a one-line pointer left in the comment. If a project's own instructions point at docs to read before touching some area, treat that as a mandatory read, not optional context, before making non-trivial changes there.

        ### readmes and other docs
        - all lowercase
        - minimal: only what someone needs to use the thing
        - no badges, no feature lists, no ai-sounding prose
        - functional over descriptive

        ## writing
        - NEVER use em dashes (—) anywhere. Not in chat, not in code comments, not in commit messages, not in docs, not in PR/issue descriptions or comments on any repo. They are ugly. Semicolons are the superior grammar for the same job (joining related clauses, parenthetical asides). Use `;`, `:`, `.`, `,`, or parens instead. En dashes (–) also out; use hyphens or restructure.
      '';
    };
}
