# Repository Guidelines

## Overview
This repository is a NixOS flake providing system configurations for multiple hosts (desktop/laptop/server) plus Home Manager modules and agenix-managed secrets.

## Project Structure & Module Organization
- `flake.nix`, `flake.lock`: flake inputs and `nixosConfigurations` entrypoints.
- `hosts/<host>/`: per-host configuration (e.g. `configuration.nix`, hardware config, `disko.nix`).
- `modules/`: reusable NixOS + Home Manager modules, grouped by area:
  - `modules/shared/` (sway-base, host-base, home-base — shared by desktop and laptop)
  - `modules/system/` (base system, hardware, network, services, desktop)
  - `modules/home/` (user programs, shell, desktop config)
  - `modules/server/`, `modules/laptop/` (role-specific overrides)
  - `modules/laptop/system/` (TLP power, boot tuning, keyboard debounce, network)
  - `modules/laptop/home/` (AC-aware swayidle, waybar with battery + power profile, auto-tab-discard Firefox)
- `configs/`: auxiliary config files consumed by modules (e.g. `configs/cloudflared.yml`).
- `secrets/`: encrypted `.age` files and `secrets/secrets.nix` (agenix access map).
- `scripts/`: helper tooling (installer, commit/rebuild helpers).

## Build, Test, and Development Commands
- `nix flake check`: quick evaluation/sanity check of the flake.
- `sudo nixos-rebuild switch --flake .#kuraokami`: build and activate a host configuration.
- `sudo nixos-rebuild build --flake .#homeserver --show-trace`: build only (useful for CI and debugging).
- `nix flake update`: update inputs; commit the resulting `flake.lock` change.
- `./scripts/install.sh`: fresh-install workflow (Disko). Review `hosts/<host>/disko.nix` first—this will wipe the selected disk.

## Coding Style & Naming Conventions
- Nix files use 2-space indentation; keep modules small and composable.
- Put host-specific tweaks in `hosts/<host>/` and reusable logic in `modules/`.
- Prefer descriptive, functional filenames (e.g. `modules/system/network/base.nix`).

## Testing Guidelines
- Before merging, build the affected host(s): `sudo nixos-rebuild build --flake .#<host> --show-trace`.
- Treat `nix flake check` as the minimum smoke test; host builds catch most regressions.

## Commit & Pull Request Guidelines
- Commit subjects are typically short and descriptive; common patterns include `host: change` and optional generation suffixes like `(Gen N)` (added by `scripts/nix-commit.zsh`).
- PRs should list affected host(s), relevant module paths, and the commands you ran (at least `nix flake check` and/or `nixos-rebuild build`).

## Security & Configuration Tips
- Never commit plaintext secrets. Add/edit secrets via agenix (`agenix -e secrets/<name>.age`) and update `secrets/secrets.nix` when changing recipients.

