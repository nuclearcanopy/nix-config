# CLAUDE.md

Guidance for working on this NixOS configuration repository. This file is a high‑signal, low‑ambiguity map for AI agents; keep it current.

## Overview
This is a personal NixOS flake for the host `kuraokami` (desktop) and `nidhoggr` (IdeaPad laptop) with home‑manager, agenix, NUR, and nixvim, plus a headless `homeserver` host in `hosts/homeserver`. It uses Sway (Wayland), low‑latency PipeWire + JACK, LACT for AMD GPU control (desktop), `scx_lavd` + ananicy for CPU scheduling, a `performance` CPU governor (desktop), Mullvad VPN, and a privacy‑tuned desktop. Bolt Launcher is wrapped with Mullvad exclusion and exposed via a desktop entry on desktop/laptop profiles. Laptop power uses aggressive TLP battery profiles (2 GHz cap, boost off on BAT; full performance on AC), AC‑aware swayidle (dim/sleep on battery, 30min idle on AC), profile‑sync‑daemon for Firefox in RAM, 80ms keyboard debounce via interception‑tools, and a waybar Fn+Q power profile indicator. Shared modules in `modules/shared/` deduplicate sway config, host base (user/locale/sudo), and home base (xdg/activation/trash) across hosts. Primary entrypoints: `flake.nix` and `hosts/<host>/configuration.nix`.

Quick entrypoints by task:
- Homeserver setup: `HOMESERVER_SETUP.md`
- Homeserver agent checklist: `HOMESERVER_AGENTS.md`
- System‑wide changes: `modules/system/*` + `hosts/<host>/system.nix`
- Home/user changes: `modules/home/home.nix` + `modules/home/*`
- Secrets wiring: `modules/system/secrets.nix` + `secrets/*`
- Hardware/partitioning: `hosts/<host>/*` + `scripts/install.sh`
- Flake inputs + `specialArgs`: `flake.nix`

## Build & Update
```bash
sudo nixos-rebuild switch --flake ~/nix-config/#kuraokami (or doas ...)
sudo nixos-rebuild switch --flake ~/nix-config/#kuraokami --show-trace (or doas ...)
nix flake update ~/nix-config
nix flake show ~/nix-config
```
- `nix-commit` (Zsh function in `modules/home/shell/zsh/nix-commit.zsh`) stages changes, rebuilds, commits with the new generation, and pushes on success.

## Secrets (Agenix)
- Mapping file: `secrets/secrets.nix` (which keys can decrypt which secrets).
- Encrypted secrets: `secrets/*.age` (e.g., `ssh-codeberg.age`, `nas-credentials.age`, `user-password.age`).
- Identity path: `/etc/age/key.txt` (provided by the user; wired in `modules/system/secrets.nix`).

The system uses agenix; do not commit plaintext secrets.

Homeserver secrets are wired in `modules/server/secrets.nix` and include `homeserver-user-password.age`, `homeserver-navidrome-env.age`, `homeserver-searxng-env.age`, `homeserver-cloudflared-credentials.age`, and `homeserver-mscd-api-hash.age`.

## Architecture
```
flake.nix               → Flake inputs and nixosConfigurations
hosts/                  → Per-host entrypoints, hardware-configuration, disko
modules/                → NixOS + home-manager modules
  shared/               → Shared modules imported by both desktop and laptop
    sway-base.nix       → Common sway keybindings, colors, gaps, window rules
    host-base.nix       → User, locale, sudo, editor (system-level)
    home-base.nix       → XDG, bolt-launcher, trash timer, activation (home-manager)
  system/               → System modules by domain
    core/               → boot, nix settings, system packages
    desktop/            → sway, fonts, xdg portal
    hardware/           → audio, gpu (LACT), cpu scheduler, openrazer, graphics
    network/            → NetworkManager, firewall, NAS mount
    services/           → polkit, flatpak, privacy toggles
  home/                 → home-manager config (desktop/kuraokami)
    desktop/            → sway config, waybar, mako, theme
    shell/              → zsh, env vars, alacritty, ssh
    programs/           → apps, firefox config, media tools
    dev/                → toolchains, claude/codex setup
  server/               → homeserver modules
  laptop/               → laptop-specific system tweaks (nidhoggr)
    system/             → TLP, boot tuning, keyboard debounce, power, network
  laptop/home/          → laptop home-manager config
    desktop/            → sway, swayidle (AC-aware), waybar (battery + power profile)
secrets/                → Encrypted secrets (*.age) and key mappings
scripts/install.sh      → disko-based install flow (fresh installs)
```

## Conventions
- Nix files use 2‑space indentation.
- Username is set once in `flake.nix` and passed via `specialArgs`.
- Unstable packages are accessed as `pkgs.unstable.<name>` where needed.
- Avoid hardcoding usernames in module bodies.
- Prefer placing new configuration in the appropriate module rather than `hosts/<host>/system.nix`.

## Adding Packages
- System: `modules/system/core/packages.nix`
- Desktop apps: `modules/home/desktop/packages.nix`
- User programs: `modules/home/programs/packages.nix`
- Dev tools: `modules/home/dev/packages.nix`
- Unfree allowlist: `modules/system/core/packages.nix`

## AI Maintenance Reminder (Mandatory)
- If you change behavior, modules, packages, or workflow, update `CLAUDE.md`, `AGENTS.md`, and `README.md` in the same PR.
- Keep summaries precise and concrete (paths, commands, ports, services, modules).
- When you see drift, update these docs before or alongside the code change.
