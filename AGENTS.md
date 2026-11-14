# Repository guidance

- Use `CLAUDE.md` as an index: read only the relevant architecture/convention section and linked `docs/<domain>.md` before non-trivial changes in that area. Don’t load the whole guide by default.
- Flake inputs and module discovery live in `flake.nix`; host wiring lives in `modules/_plumbing/nixos.nix` and `modules/computers/`; reusable system and Home Manager modules live in `modules/<domain>/`.
- Keep host hardware and disk layouts in `hosts/<host>/`. Keep plaintext secrets out of the repository; use agenix.
- Verify Nix changes by evaluating the affected flake output (for example, `nix eval .#nixosConfigurations.nidhoggr.config.system.build.toplevel.drvPath --raw`). Never run `nixos-rebuild switch`.
- Update `CLAUDE.md` or a domain doc only when a non-obvious behavior, constraint, or design rationale would otherwise be lost; keep this file short and use the detailed map rather than duplicating it.
- **Commit and push each completed change immediately.** Once a logically complete, independently verified change is ready, stage only its intended hunks, inspect the staged diff, commit it, and push it before starting another change. Preserve pre-existing work unless the user explicitly asks to commit it; group authorized changes into logical commits. If unrelated overlapping edits cannot be isolated safely, stop and report the exact blocker.
