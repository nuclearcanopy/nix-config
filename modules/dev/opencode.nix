{
  homeManager.modules.opencode = { config, lib, pkgs, ... }:
    let
      jsonFormat = pkgs.formats.json { };
      instructions = import ./agent-instructions.data.nix;
      instructionsFile = pkgs.writeText "agent-instructions.md" instructions;
      opencodeInstructionsFile = pkgs.writeText "opencode-workflow.md" ''
        - On every actionable implementation request, begin the work in this turn. Do not stop after acknowledging, promising, planning, or asking whether to proceed when the requested next step is clear. Keep narration minimal; actions and verified outcomes are the deliverable.
        - Match effort to the requested outcome, not the smallest plausible patch. For broad requests, inspect the end-to-end behavior and relevant architecture, identify root causes and affected paths, then make a coherent solution across the necessary code, configuration, tests, and docs. Preserve unrelated work; do not mistake narrow diffs for good judgment.
        - Use bounded initiative: make routine choices from repository conventions, pursue clearly necessary adjacent fixes, and verify the whole requested outcome. Do not ask permission for ordinary reversible implementation decisions. Ask only for genuine ambiguity that blocks safe progress or a required approval (secrets, auth, destructive/irreversible actions, or other consequential changes). If blocked, first investigate viable alternatives and report the precise blocker and remaining work.
        - Before handing off, inspect the complete diff and status, run the relevant checks, fix failures where possible, and distinguish verified results from unchecked work. A plan, partial patch, or unverified claim is not completion.
        - For unfamiliar areas, selectively delegate investigation to `explorer`; for substantial or risky changes, independently review with `reviewer`. Use delegation to improve coverage, not to defer work or replace the parent agent's responsibility to integrate, verify, and finish. Do not use a swarm.
        - Give subagents focused context. For reviews, include the goal, changed paths, full diff, verification performed, and open questions. Assess findings yourself; do not accept them blindly.
        - `reviewer` is configured without file-edit or shell access, but treat it as a read-only role, not a security sandbox. Do not give it secrets or ask it to perform session/worktree operations.
        - Use the `nixos` MCP to look up NixOS options/packages when useful. Treat its results as a discovery aid; check the pinned flake/nixpkgs source before relying on version-sensitive details.
      '';
      explorerAgent = pkgs.writeText "opencode-explorer.md" ''
        ---
        description: Investigates unfamiliar code and documentation, then reports concise findings without editing
        mode: subagent
        permissions:
          - action: "*"
            resource: "*"
            effect: deny
          - action: read
            resource: "*"
            effect: allow
          - action: glob
            resource: "*"
            effect: allow
          - action: grep
            resource: "*"
            effect: allow
          - action: webfetch
            resource: "*"
            effect: allow
          - action: websearch
            resource: "*"
            effect: allow
        ---

        Investigate the requested area by reading relevant files and documentation. Report the key paths, how the
        relevant pieces fit together, important constraints, and unanswered questions. Do not edit files or run
        commands that change state. Keep the report focused so the parent agent can act on it.
      '';
      reviewerAgent = pkgs.writeText "opencode-reviewer.md" ''
        ---
        description: Independently reviews substantial changes for bugs, regressions, and missing verification
        mode: subagent
        permissions:
          - action: "*"
            resource: "*"
            effect: deny
          - action: read
            resource: "*"
            effect: allow
          - action: glob
            resource: "*"
            effect: allow
          - action: grep
            resource: "*"
            effect: allow
        ---

        Independently review the requested changes using the diff and file paths supplied by the parent, plus relevant
        surrounding code. Report actionable findings, ordered by severity, with file and line references. Focus on correctness, regressions,
        security, and missing tests or verification. Do not edit files or make commits. If there are no findings, say so
        and note any remaining verification gaps.
      '';
    in
    {
      # opencode still loads the obsolete config.json before the managed
      # opencode.json; remove stale pre-migration settings after HM links the
      # generation so the legacy filename remains absent.
      home.activation.removeLegacyOpencodeConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        legacy="${config.home.homeDirectory}/.config/opencode/config.json"
        if [ -e "$legacy" ] || [ -L "$legacy" ]; then
          $DRY_RUN_CMD rm "$legacy"
        fi
      '';
      home.file.".config/opencode/AGENTS.md".source = instructionsFile;
      home.file.".config/opencode/workflow.md".source = opencodeInstructionsFile;
      home.file.".config/opencode/agents/explorer.md".source = explorerAgent;
      home.file.".config/opencode/agents/reviewer.md".source = reviewerAgent;
      home.file.".config/opencode/opencode.json".source = jsonFormat.generate "opencode.json" {
        "$schema" = "https://opencode.ai/config.json";
        model = "anthropic/claude-sonnet-5-5";
        default_agent = "build";
        agents.build.model = "anthropic/claude-sonnet-5-5#medium";
        agents.plan.model = "anthropic/claude-opus-5-5#medium";
        experimental.todo = true;
        mcp.servers.nixos = {
          type = "local";
          command = [ "${pkgs.mcp-nixos}/bin/mcp-nixos" ];
        };
        permissions = [
          { action = "*"; resource = "*"; effect = "ask"; }
          { action = "external_directory"; resource = "*"; effect = "ask"; }
          { action = "read"; resource = "*"; effect = "allow"; }
          { action = "edit"; resource = "*"; effect = "allow"; }
          { action = "glob"; resource = "*"; effect = "allow"; }
          { action = "grep"; resource = "*"; effect = "allow"; }
          { action = "skill"; resource = "*"; effect = "allow"; }
          { action = "question"; resource = "*"; effect = "allow"; }
          { action = "webfetch"; resource = "*"; effect = "allow"; }
          { action = "websearch"; resource = "*"; effect = "allow"; }
          { action = "subagent"; resource = "*"; effect = "allow"; }
          { action = "shell"; resource = "*"; effect = "allow"; }
          { action = "shell"; resource = "sudo *"; effect = "ask"; }
          { action = "shell"; resource = "doas *"; effect = "deny"; }
          { action = "shell"; resource = "rm -r *"; effect = "deny"; }
          { action = "shell"; resource = "rm -fr *"; effect = "deny"; }
          { action = "shell"; resource = "rm --recursive *"; effect = "deny"; }
          { action = "shell"; resource = "mkfs *"; effect = "deny"; }
          { action = "shell"; resource = "wipefs *"; effect = "deny"; }
          { action = "shell"; resource = "dd *"; effect = "deny"; }
          { action = "shell"; resource = "shred *"; effect = "deny"; }
        ];
        instructions = [
          "${config.home.homeDirectory}/.config/opencode/AGENTS.md"
          "${config.home.homeDirectory}/.config/opencode/workflow.md"
        ];
      };
    };
}
