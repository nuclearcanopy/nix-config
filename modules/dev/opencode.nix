{
  homeManager.modules.opencode = { config, pkgs, ... }:
    let
      jsonFormat = pkgs.formats.json { };
      instructions = ''
        You are working on a NixOS system. Make all fixes declaratively and reproducibly; do not use imperative system management when a Nix configuration change is possible.

        The active host is inferred from the cwd, hostname, edited host module, or running processes. This setup targets nidhoggr, a ThinkPad T480, unless the repository context says otherwise. State the inference when it matters and ask only when genuinely ambiguous. The configuration lives at ~/nix-config.

        ## workflow
        - Inspect the relevant files and project instructions before editing.
        - Use parallel subagents for independent multi-part work; skip them for trivial lookups.
        - Make the smallest correct change. Do not add compatibility code without a concrete need.
        - Preserve unrelated user changes. Never reset, checkout, or otherwise discard them.
        - Use `apply_patch` for manual edits.
        - Read the relevant `docs/*.md` before changing a domain with documented history.
        - Do not run `nixos-rebuild switch`; stop after evaluation or a build and leave switching to the user.
        - Do not run full flake verification after every edit; run it before handoff or when requested.

        ## Nix conventions
        - Put system changes in the relevant `modules/<domain>/` bucket and wire host-specific modules from `modules/computers/<host>.nix`.
        - Put user changes in the relevant Home Manager module.
        - Use two-space Nix indentation and ASCII by default.
        - Never commit plaintext secrets. Keep secrets in agenix and do not expose identity values.
        - Prefer existing packages, helpers, and module patterns over new abstractions.

        ## git
        This is the user's own repository. Once the requested change works and verification passes, commit and push to the `github` remote by default. Use small, coherent commits with lowercase, dense technical subjects; no AI co-author trailer.

        Ask before committing or pushing if verification failed, the change affects secrets/auth/exposed services or is hard to reverse, or the repository is an external contribution. Before a PR, inspect all common pull request templates and follow the target project's AI disclosure policy. Never claim a test or build passed unless it ran in this session.

        ## writing
        Keep responses direct and concise. Findings come first in reviews. Comments should explain only load-bearing behavior; put forensic history in docs. Keep README and documentation prose lowercase, minimal, and functional. Never use em dashes or en dashes.
      '';
    in
    {
      home.file.".config/opencode/AGENTS.md".text = instructions;
      home.file.".config/opencode/opencode.json".source = jsonFormat.generate "opencode.json" {
        "$schema" = "https://opencode.ai/config.json";
        shell = "${pkgs.zsh}/bin/zsh";
        share = "disabled";
        snapshots = true;
        instructions = [ "${config.home.homeDirectory}/.config/opencode/AGENTS.md" ];
        tool_output = {
          max_lines = 120;
          max_bytes = 16384;
        };
        compaction = {
          auto = true;
          keep.tokens = 12000;
        };
      };
    };
}
