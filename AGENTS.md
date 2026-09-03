# Repository Guidelines

## Overview
This repository is a NixOS flake providing system configurations for multiple hosts (desktop/laptop/server) plus Home Manager modules and agenix-managed secrets.

## Project Structure & Module Organization
- `flake.nix`, `flake.lock`: flake inputs and `nixosConfigurations` entrypoints.
- `hosts/<host>/`: per-host configuration (e.g. `configuration.nix`, hardware config, `disko.nix`).
- `modules/`: reusable NixOS + Home Manager modules, grouped by area:
  - `modules/shared/` (sway-base, host-base, home-base; shared by desktop and laptop)
  - `modules/system/` (base system, hardware, network, services, desktop)
  - `modules/home/` (user programs, shell, desktop config)
  - `modules/server/`, `modules/laptop/` (role-specific overrides)
  - `modules/laptop/system/` (TLP power, boot tuning, keyboard debounce, network, trackpad Synaptics PS/2 rate=200 with coreboot SMBus enable)
  - `modules/laptop/home/` (AC-aware swayidle, waybar with battery + power profile + airgap toggle, auto-tab-discard Firefox)
- `configs/`: auxiliary config files consumed by modules (e.g. `configs/cloudflared.yml`).
- `secrets/`: encrypted `.age` files and `secrets/secrets.nix` (agenix access map).
- `scripts/`: helper tooling (installer, commit/rebuild helpers).

## Build, Test, and Development Commands
- `nix flake check`: quick evaluation/sanity check of the flake.
- `sudo nixos-rebuild switch --flake .#kuraokami`: build and activate a host configuration.
- `sudo nixos-rebuild build --flake .#homeserver --show-trace`: build only (useful for CI and debugging).
- `nix flake update`: update inputs; commit the resulting `flake.lock` change.
- `./scripts/install.sh`: fresh-install workflow (Disko). Review `hosts/<host>/disko.nix` first; this will wipe the selected disk.

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
- Never commit plaintext secrets. The `agenix` CLI is not installed; add or rotate a secret by listing the filename in `secrets/secrets.nix` and encrypting directly with `age -r <recipient-from-secrets.nix> -o secrets/<name>.age <plaintext>`. New `.age` files must be `git add`-ed before the flake can see them.
- Eval-time values (usernames) cannot be agenix secrets, because agenix decrypts at activation and the evaluator needs them sooner. They live in the private `identity` flake input (`git+ssh://git@github.com/nuclearcanopy/identity.git`), read as `inputs.identity.usernames.<host>`. Read access to that repo is required to evaluate this flake; without it every command below fails with a git fetch error.
- The public GitHub mirror means any pasted secret leaks; for on-`homeserver` rotations of secrets in `kurai_only` `.age` files, drop an override env file at `/var/lib/<service>/<purpose>.env` (mode 600, root:root) and append its path to the container's `environmentFiles` list after the agenix entry — docker resolves duplicate keys "last wins". Example in `services.nix`: `/var/lib/navidrome/lastfm.env`.

## Homeserver streaming sidecar
- `navidrome-boost.service` in `modules/server/services.nix` tails the Navidrome container journal and toggles the CPU governor between `powersave` and `performance` based on stream/scan activity (120s idle drop). If you lower `ND_LOGLEVEL` below `info`, the trigger lines stop being emitted and the boost stops working — keep it at `info`.
- The homeserver `cloudflared` container runs with `--protocol quic --ha-connections 4` and publishes its metrics endpoint on `127.0.0.1:44483` (`--metrics 0.0.0.0:44483`) so the watchdog can poll `/ready`; don't drop the HA flag or the metrics port when changing the tunnel block.

## Homeserver failsafes
- `modules/server/watchdog.nix` (`server-watchdog`, imported in `modules/computers/homeserver.nix`) is the crash/hang recovery layer for the flaky laptop hardware. It forces `Restart=always` on the docker daemon and on every container unit (`docker-filebrowser`/`docker-portainer`/`docker-cloudflared`; navidrome already forces it in `services.nix`), enables `earlyoom` (notifications off, headless), and runs `server-watchdog.timer` every 2 min.
- The timer runs `modules/server/scripts/healthcheck.sh`: curls navidrome `:4533/`, filebrowser `:8081/health`, portainer `:9000/api/status`, cloudflared `:44483/ready`, and `docker ps`. Escalation ladder per target (checks ~2 min apart): 1 fail → restart that container unit; ≥2 fails → bounce the whole docker stack (daemon + `init-docker-network` + all containers); ≥6 fails → `systemctl reboot`. Failure counters live in `/run/server-watchdog` (tmpfs) so a reboot always starts clean and a permanently-broken service can't boot-loop.
- This sits on top of the existing hard-failure defenses in `server-system`: hardware watchdog (`RuntimeWatchdogSec=60s`), `panic_on_oops=1`, `kernel.panic=30`, and the daily 05:00 reboot.

