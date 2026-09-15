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

## Laptop software minimalism (nidhoggr)
- `nidhoggr` is kept deliberately lean. Price anything new with `nix path-info -S` before adding it, and prefer the smaller option; see the "Laptop software minimalism" section in `CLAUDE.md` for what was removed on 2026-09-06 and why.
- Consequences worth knowing: `lyx` has no TeX backend since `texliveFull` went, `EnableMangoHud=true` must not be set in a Prism `instance.cfg` here, the file manager is `pcmanfm` (kuraokami keeps `thunar`), and `openrazer` is kuraokami-only even though a Razer mouse is used on both (nidhoggr's mouse battery comes from solaar instead; see below).
- USBGuard blocks unknown devices on insert. `usbguard-notifier` raises a notification, and **Mod+Shift+U** opens a bemenu picker (`modules/gui/waybar/scripts/usb_allow.sh`) that authorizes a blocked device until reboot. Permanent trust still means adding `allow id <vid>:<pid>` to `modules/security/hardening-physical.nix` and rebuilding.

## User services and session targets
- Home-manager user services must hang off `sway-session.target`, never `graphical-session.target`. NixOS's `nixos-fake-graphical-session.target` activates `graphical-session.target` at login, before sway runs `systemctl --user import-environment`, so anything ordered on it starts with no `WAYLAND_DISPLAY`/`QT_PLUGIN_PATH`. `easyeffects` was the last service on the stock HM wiring and SIGABRTed every boot on Qt platform-plugin init; fixed 2026-09-15 in `modules/programs/easyeffects-service.nix`.
- Overriding HM unit sections: list keys under `.Unit` merge by concatenation, so `After`/`PartOf`/`Install.WantedBy` need `lib.mkForce` or the old target stays wired alongside the new one. Keep the pipewire ordering on `easyeffects` regardless; without it it aborts on `No connection to PipeWire`.
- A service with `Restart=on-failure` can crash on every boot and still read `active (running)` seconds later. `systemctl --failed` will not show it; check `coredumpctl list` when auditing.

## Journal and PCIe AER noise
- `modules/services/core.nix` caps journald at `SystemMaxUse=512M` / `SystemMaxFileSize=64M` / `MaxRetentionSec=1month`; the default is 10% of the root fs (~23G) and it had reached 2.1G.
- Most of that volume is ~1000 correctable `RxErr` AER retries per boot from the WD PC SN720 NVMe (`0000:07:00.0`). They are harmless link-layer retries. **Do not disable AER** (`pci=noaer`, `pcie_ports=compat`) to quiet them; the AX210 resume failure is detected as a fatal AER event and would be hidden.

## Mouse battery (waybar `custom/mouse`)
- `mouse_battery.sh` tries openrazer sysfs, then `/sys/class/power_supply/hidpp_battery_0`, then `solaar show`. The first is kuraokami-only; the second never fires on nidhoggr, because its receiver (`046d:c547`, G502 X Lightspeed) is in no kernel HID++ id table, binds `hid-generic`, and so gets no power-supply node. There is no in-tree driver to load or bind; solaar reads it from userspace over hidraw.
- `modules/hardware/logitech.nix` supplies `logitech-udev-rules` (uaccess ACL on `046d` hidraw nodes) and `solaar`. uaccess applies on device add, so the receiver must be replugged after a rebuild that first adds the rules. Don't swap this for `hardware.logitech.wireless.enable`; it drags in Unifying-only `ltunify`.
- solaar costs ~3.5s wall / ~1.2s CPU per call and can't be made cheaper, so the laptop polls at 300s and relies on `signal = 13` (`pkill --signal 47 waybar`, fired from `resumeCommands` after the receiver is re-authorized) to refresh on resume. See the "Mouse battery" section in `CLAUDE.md`.

## Neovim (nixvim)
- Config is `modules/programs/neovim.nix` plus `modules/programs/neovim/init.lua` (`extraConfigLua`). `typos_lsp` is the only server, and because its lspconfig entry declares no `filetypes`, nvim 0.12 attaches it to every buffer with `buftype` `''` or `help`.
- `extraOptions.flags.allow_incremental_sync = false` is deliberate: nvim 0.12's incremental sync asserts in `vim/lsp/sync.lua:136` (`compute_start_range`) when its cached line snapshot desyncs from the buffer (neovim#33224). The flag forces Full sync so `compute_diff` never runs. Don't remove it until upstream fixes the assert.

## Homeserver streaming sidecar
- `navidrome-boost.service` in `modules/server/services.nix` tails the Navidrome container journal and toggles the CPU governor between `powersave` and `performance` based on stream/scan activity (120s idle drop). If you lower `ND_LOGLEVEL` below `info`, the trigger lines stop being emitted and the boost stops working — keep it at `info`.
- The homeserver `cloudflared` container runs with `--protocol quic --ha-connections 4` and publishes its metrics endpoint on `127.0.0.1:44483` (`--metrics 0.0.0.0:44483`) so the watchdog can poll `/ready`; don't drop the HA flag or the metrics port when changing the tunnel block.

## Homeserver failsafes
- `modules/server/watchdog.nix` (`server-watchdog`, imported in `modules/computers/homeserver.nix`) is the crash/hang recovery layer for the flaky laptop hardware. It forces `Restart=always` on the docker daemon and on every container unit (`docker-filebrowser`/`docker-portainer`/`docker-cloudflared`; navidrome already forces it in `services.nix`), enables `earlyoom` (notifications off, headless), and runs `server-watchdog.timer` every 2 min.
- The timer runs `modules/server/scripts/healthcheck.sh`: curls navidrome `:4533/`, filebrowser `:8081/health`, portainer `:9000/api/status`, cloudflared `:44483/ready`, and `docker ps`. Escalation ladder per target (checks ~2 min apart): 1 fail → restart that container unit; ≥2 fails → bounce the whole docker stack (daemon + `init-docker-network` + all containers); ≥6 fails → `systemctl reboot`. Failure counters live in `/run/server-watchdog` (tmpfs) so a reboot always starts clean and a permanently-broken service can't boot-loop.
- This sits on top of the existing hard-failure defenses in `server-system`: hardware watchdog (`RuntimeWatchdogSec=60s`), `panic_on_oops=1`, `kernel.panic=30`, and the daily 05:00 reboot.

