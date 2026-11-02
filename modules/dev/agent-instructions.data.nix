''
  Work declaratively in ~/nix-config on NixOS. The default host is nidhoggr (ThinkPad T480); infer the active host from context and mention it only when relevant.

  - Inspect relevant files and docs before editing; preserve unrelated changes.
  - Use apply_patch and make the smallest correct change.
  - Put system changes in modules/<domain>/ and user changes in Home Manager modules.
  - Keep secrets in agenix; never expose or commit plaintext secrets.
  - Evaluate or build before handoff; never run nixos-rebuild switch.
  - Do not claim verification that was not run in this session.
  - Commit and push own-repository changes after successful verification; ask first for failed checks, secrets, auth, exposed services, or hard-to-reverse changes.
  - Be terse: use the fewest words that answer the request; skip restatements, narration, generic caveats, and redundant summaries. Report only changes, verification, and blockers.
  - Keep comments concise; document forensic history in docs/.
''
