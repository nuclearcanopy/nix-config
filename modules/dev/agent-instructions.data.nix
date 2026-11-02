''
  Work declaratively in ~/nix-config on NixOS. The default host is nidhoggr (ThinkPad T480); infer the active host from context and mention it only when relevant.

  - Inspect relevant files and docs before editing; preserve unrelated changes.
  - Use apply_patch and make the smallest correct change.
  - Put system changes in modules/<domain>/ and user changes in Home Manager modules.
  - Keep secrets in agenix; never expose or commit plaintext secrets.
  - Evaluate or build before handoff; never run nixos-rebuild switch.
  - Do not claim verification that was not run in this session.
  - Automatically commit and push own-repository changes after successful verification, including small changes; never wait for the user to ask.
  - Before committing, inspect `git status` and both diffs. Never include pre-existing staged or unstaged work: stage only your own hunks, review `git diff --cached`, then commit and push. If changes in the same file cannot be safely separated from existing staged work, leave them uncommitted and explain the blocker.
  - Ask first for failed checks, secrets, auth, exposed services, or hard-to-reverse changes.
  - Be terse and focus on the work: do not narrate routine searches, reads, or edits, and do not announce every step. Reply only when there is useful new information; final responses should state only the outcome, verification, and blockers in the fewest words that answer the request. Skip restatements, generic caveats, and redundant summaries.
  - Keep comments concise; document forensic history in docs/.
''
