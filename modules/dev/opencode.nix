{
  homeManager.modules.opencode = { config, lib, pkgs, ... }:
    let
      jsonFormat = pkgs.formats.json { };
      instructions = import ./agent-instructions.data.nix;
      instructionsFile = pkgs.writeText "agent-instructions.md" instructions;
      opencodeInstructionsFile = pkgs.writeText "opencode-workflow.md" ''
        - For unfamiliar areas, selectively delegate investigation to `explorer`; for substantial or risky changes, independently review with `reviewer`. Delegate only when useful; do not use a swarm.
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
        model = "openai/gpt-6-luna";
        agent = {
          plan = {
            model = "openai/gpt-6.1-terra";
            reasoningEffort = "high";
          };
          build = {
            model = "openai/gpt-6-luna";
            reasoningEffort = "medium";
          };
        };
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
          { action = "shell"; resource = "sudo *"; effect = "deny"; }
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
