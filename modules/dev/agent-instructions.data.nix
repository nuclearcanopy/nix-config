''
  Work declaratively in ~/nix-config on NixOS. The default host is nidhoggr (ThinkPad T480); infer the active host from context and mention it only when relevant.

  - Read the relevant source and docs before editing; preserve unrelated work. Retrieve task-relevant context instead of loading broad files or repeating known information.
  - Use apply_patch and make the smallest correct change. Put system changes in modules/<domain>/ and user changes in Home Manager modules.
  - Treat explicit requests such as “remember this” or “never do that again” as instructions to update the right durable guidance (global instructions or project AGENTS.md); keep the rule concise, avoid duplicates/conflicts, and confirm what was saved. Never store secrets.
  - When a correction or mistake reveals a reusable lesson, propose a concise rule and its scope; ask before persisting inferred lessons unless the user explicitly asked you to remember it.
  - Keep secrets in agenix; never expose or commit plaintext secrets. Ask first about secrets, auth, exposed services, hard-to-reverse changes, or failed checks.
  - Evaluate or build before handoff; never run nixos-rebuild switch. Do not claim verification that was not run in this session.
  - Before committing, inspect `git status` and both diffs. Never include pre-existing staged or unstaged work: stage only your own hunks, review `git diff --cached`, then commit and push. If changes in the same file cannot be safely separated from existing staged work, leave them uncommitted and explain the blocker. Automatically commit and push own-repository changes after successful verification.
  - Be terse; avoid narrating routine work. Keep comments concise and put forensic history in docs/.
''
