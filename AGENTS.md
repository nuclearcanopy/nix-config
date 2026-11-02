# Repository guidance

- Read `CLAUDE.md` for the architecture map, conventions, and relevant domain history; read the linked `docs/<domain>.md` before non-trivial changes in those areas.
- Flake inputs and module discovery live in `flake.nix`; host wiring lives in `modules/_plumbing/nixos.nix` and `modules/computers/`; reusable system and Home Manager modules live in `modules/<domain>/`.
- Keep host hardware and disk layouts in `hosts/<host>/`. Keep plaintext secrets out of the repository; use agenix.
- Verify Nix changes by evaluating the affected flake output (for example, `nix eval .#nixosConfigurations.nidhoggr.config.system.build.toplevel.drvPath --raw`). Never run `nixos-rebuild switch`.
- Update `CLAUDE.md` or a domain doc only when a non-obvious behavior, constraint, or design rationale would otherwise be lost; keep this file short and use the detailed map rather than duplicating it.
