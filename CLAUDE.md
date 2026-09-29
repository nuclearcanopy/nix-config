# CLAUDE.md

Guidance for working on this NixOS configuration repository. This file is a high‑signal, low‑ambiguity map for AI agents; keep it current.

## Overview
This is a personal NixOS flake for the host `kuraokami` (desktop) and `nidhoggr` (ThinkPad T480 laptop) with home‑manager, agenix, NUR, and nixvim, plus a headless `homeserver` host in `hosts/homeserver`. It uses Sway (Wayland), low‑latency PipeWire + JACK, LACT for AMD GPU control (desktop), `scx_lavd` + ananicy for CPU scheduling, a `performance` CPU governor (desktop), Mullvad VPN (sole VPN provider, lockdown mode on nidhoggr), and a privacy‑tuned desktop. Both hosts run the CachyOS kernel (`pkgs.cachyosKernels.linuxPackages-cachyos-latest-x86_64-v3`); kuraokami in `modules/boot/boot-amd.nix`, nidhoggr in `modules/boot/boot-t480.nix`. Laptop power uses aggressive TLP battery profiles, AC‑aware swayidle, profile‑sync‑daemon for Firefox in RAM, 40ms keyboard debounce, and a waybar power-mode indicator (`set-cpu-mode {spd|bal|lap|god|auto}`, sticky via `/var/lib/cpu-mode/state`). Laptop NetworkManager randomizes the MAC on every wifi/ethernet connection. Desktop theming (`modules/gui/theme.nix`) is a pitch-black OLED palette mirrored into a Qt6 palette for Helium/Chromium. `allowedUnfree` is defined once in `flake.nix` and passed via `specialArgs`; homeserver's `username = "homeserver"` is in `specialArgs` too. Primary entrypoints: `flake.nix` and `hosts/<host>/hardware-configuration.nix`.

### `docs/` — read before touching these domains
Deep forensic detail (incident timelines, root-cause investigations, declined alternatives) lives in `docs/<domain>.md`, not inline in module comments. Inline comments carry a short load-bearing fact plus a pointer to the relevant doc section. **Before making a non-trivial change to a domain listed below, read its doc first** — the doc is the actual history, the module comment is only a breadcrumb.

- `docs/power.md` — AX210 resume-from-S3 failures and mitigations, battery threshold drift/boot-race. Relevant: `modules/power/power-suspend.nix`, `modules/power/tlp.nix`, `modules/boot/boot-t480.nix`.
- `docs/networking.md` — Mullvad dispatcher/relink rewrite history (SIGPIPE bug, stale-cache disconnect incident, lockdown mode). Relevant: `modules/networking/network-laptop.nix`.
- `docs/gui.md` — Helium/Chromium Qt palette investigation (why chrome can't be both pure-black and show a visible active tab). Relevant: `modules/gui/theme.nix`.
- `docs/trackpad-tm3471.md` — aftermarket Synaptics trackpad bring-up (coreboot + kernel + libinput). Relevant: `modules/hardware/trackpad-synaptics.nix`, `modules/gui/sway-host.nix`.
- `docs/battery-model.md` — how the adaptive battery runtime estimator works (conditioning, calibration, storage). Relevant: `modules/power/battery-model.nix`, `modules/power/scripts/battery_model.py`.

Other systems with real design depth but no incident history stay inline or in the sections below: waybar airgap toggle (`modules/gui/waybar/scripts/airgap_{mode,toggle}.sh`), USBGuard block-by-default + Mod+Shift+U allow flow (`modules/security/hardening-physical.nix`), bluetooth toggle (`modules/hardware/bluetooth.nix`).

Quick entrypoints by task:
- Homeserver: `modules/computers/homeserver.nix` + `modules/server/*`
- System‑wide changes: the relevant `modules/<domain>/*` bucket, then import it from `modules/computers/<host>.nix`
- Home/user changes: the `homeManager.modules.*` buckets (`modules/gui/*`, `modules/programs/*`, `modules/shell/*`, `modules/dev/*`)
- Secrets wiring: `modules/base/secrets.nix` (+ `modules/server/secrets.nix`) + `secrets/*`
- Hardware/partitioning: `hosts/<host>/*` + `scripts/install.sh`
- Flake inputs + `specialArgs`: `flake.nix`
- Deep rationale/incident history: `docs/*.md` (see above)

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
- Encrypted secrets: `secrets/*.age` (e.g., `ssh-git.age`, `ssh-github.age`, `nas-credentials.age`, `user-password.age`).
- Identity path: `/etc/age/key.txt` (provided by the user; wired in `modules/base/secrets.nix`).

The system uses agenix; do not commit plaintext secrets.

Two SSH keys, split by purpose: `ssh-git.age` → `/run/agenix/ssh-git` is the homeserver login key (laptop/desktop → homeserver; the matching pubkey is in `modules/server/users.nix` `authorizedKeys` and is materialized locally at `~/.ssh/id_ed25519_homeserver.pub`), and `ssh-github.age` → `/run/agenix/ssh-github` is the git forge key for `github.com` (pubkey at `~/.ssh/id_ed25519_github.pub`). Both are declared in `modules/base/secrets.nix` and routed in `modules/shell/ssh.nix`; the homeserver gets `ssh-github` symlinked to `~/.ssh/id_github` by `modules/server/git.nix` so it can pull the flake. `agenix` is not installed as a CLI; to add or rotate a secret, add the filename to `secrets/secrets.nix` and encrypt directly with `age -r <recipient-from-secrets.nix> -o secrets/<name>.age <plaintext>` (all three hosts share the one age recipient, so a single `-r` matches what agenix would emit). New `.age` files must be `git add`-ed before the flake can see them.

GitHub is the only forge. The repo lives at `github.com/nuclearcanopy/nix-config`, the remote is named `github`, and there is no second remote; `nix-commit`/`nix-clone` push and pull `github main`.

## Private identity flake (eval-time values)
Agenix decrypts at **activation** time, which is far too late for anything the Nix **evaluator** needs: `username` feeds `users.users.<name>`, home-manager paths, and agenix's own `owner =`. A username therefore cannot be an agenix secret; there is no version of that which works. Values in that class live in a separate private flake, `git+ssh://git@github.com/nuclearcanopy/identity.git`, wired as the `identity` input in `flake.nix` and read as `inputs.identity.usernames.<host>`. Currently it holds only `usernames.kuraokami`, since `nidhoggr` (`loki`) and `homeserver` are already public. Consequences: **read access to that repo is required to evaluate this flake at all** (a missing key surfaces as a git fetch error, not a Nix error), `flake.lock` pins its rev and URL but never its contents, and the fetched source does land world-readable in `/nix/store` on the machine itself, so this hides the value from the public repo, not from a local user. To rotate or add a value, commit to the identity repo and run `nix flake lock --update-input identity`.

Homeserver secrets are wired in `modules/server/secrets.nix` and include `homeserver-user-password.age`, `homeserver-navidrome-env.age`, `homeserver-searxng-env.age`, `homeserver-cloudflared-credentials.age`, and `homeserver-mscd-api-hash.age`.

## Homeserver streaming reliability (`modules/server/services.nix`)
Navidrome is configured for resilient Subsonic streaming: 5GB transcoding cache, 500MB image cache, opus default downsampling, 6h scan schedule, 168h sessions, downloads enabled, scan log lines remain at `info` level (the boost sidecar trigger needs them). The container's `environmentFiles` list reads `homeserver-navidrome-env.age` AND a local mode-600 file at `/var/lib/navidrome/lastfm.env` (the latter wins per docker env-file "last duplicate key wins"; it lets us rotate the Last.fm API key on-host without re-encrypting the agenix secret, which is only decryptable from `kuraokami`). `docker-navidrome.service` has `Restart=always` with 5s backoff.

A sidecar systemd unit `navidrome-boost.service` (defined in the same file) tails the Navidrome container's journal for `Streaming file` / `GET /rest/stream` / `GET /rest/download` / `Scanner` lines and flips the CPU scaling governor between `powersave` (idle) and `performance` (active), with a 120s idle drop watchdog. State lives at `/run/navidrome-boost/last-activity`. This was added to keep the i5-5200U responsive under transcoding load without globally pinning the governor to performance.

The `cloudflared` container runs with `--protocol quic --ha-connections 4`. Defaults (HTTP/2, single connection) were a streaming bottleneck that manifested as Subsonic skips and "song unavailable" errors. It also runs `--metrics 0.0.0.0:44483` and publishes that port to `127.0.0.1:44483` so the watchdog can poll `/ready` (200 = ≥1 tunnel connection up).

## Homeserver failsafes (`modules/server/watchdog.nix`)
The homeserver runs on aging laptop hardware and cuts out often, so `server-watchdog` (module `nixos.modules.server-watchdog`, imported in `modules/computers/homeserver.nix`) is a crash/hang recovery layer on top of the hard-failure defenses already in `server-system` (hardware watchdog `RuntimeWatchdogSec=60s`, `panic_on_oops=1`, `kernel.panic=30`, daily 05:00 reboot). It:
- Forces `Restart=always` (`RestartSec=5s`) on the docker daemon and on every container unit. Previously only `docker-navidrome` restarted on crash (forced in `services.nix`); `docker-filebrowser`/`docker-portainer`/`docker-cloudflared` relied on the oci-containers default (no restart) and a crash stranded them until the next boot. The watchdog module adds the force for those three; navidrome keeps its own.
- Enables `services.earlyoom` (freeMem 5%, freeSwap 10%, notifications off since headless) to kill the fattest process before the kernel OOM-killer hard-locks the box.
- Runs `server-watchdog.timer` every 2 min (`OnBootSec=3min`, `OnUnitActiveSec=2min`) executing `modules/server/scripts/healthcheck.sh`.

The health-check script curls `docker ps` plus navidrome `:4533/`, filebrowser `:8081/health`, portainer `:9000/api/status`, and cloudflared `:44483/ready`. Escalation ladder per target (checks ~2 min apart): **1 fail** → restart just that container unit; **≥2 fails** → bounce the whole docker stack (`docker.service` + `init-docker-network.service` + all container units); **≥6 fails** → `systemctl reboot`. The docker-daemon check is first and hardest: if `docker ps` times out (20s), it restarts `docker.service` immediately and reboots after 6 consecutive wedges. Failure counters live in `/run/server-watchdog` (tmpfs) on purpose so a reboot always starts from a clean slate and a permanently-broken service can never turn into a boot loop. To add a monitored service, append a `check <name> <url> <container-unit>` line and add the unit to `CONTAINERS`.

## Architecture
```
flake.nix               → Flake inputs, nixosConfigurations, allowedUnfree, module auto-discovery
hosts/<host>/           → Per-host hardware-configuration + disko (kuraokami, nidhoggr, homeserver)
modules/                → NixOS + home-manager modules, grouped by domain
  _plumbing/            → nixos.nix / home-manager.nix: the option scaffolding modules register into
  computers/            → Per-host entrypoints (kuraokami.nix, nidhoggr.nix, homeserver.nix)
                          plus desktop-profile.nix, the shared desktop/laptop profile
  base/                 → host-base, home-base, secrets, docker, earlyoom, state-version,
                          system-packages-{baseline,laptop}
  boot/                 → boot-amd, boot-t480, boot-optimizations, luks-initrd, tpm2-off,
                          displaymanager-ly
  gui/                  → sway-{base,host,startup,system}, waybar (+ scripts/), mako, theme,
                          fonts, xdg-portal, swayidle, bemenu-style.data.nix
  hardware/             → audio, graphics (amd/intel), gpu-amd (LACT), cpu scheduler/governor,
                          bluetooth, openrazer, logitech, trackpoint, trackpad-synaptics,
                          v4l2loopback
  networking/           → base, network-laptop (Mullvad lockdown/relink), mullvad-*, nas-mount
  power/                → tlp, cpu-modes, thinkfan, undervolt, power-suspend, brightness-persist,
                          battery-model (+ scripts/battery_model.py)
  programs/             → firefox, neovim, gaming, virtualisation, thunar, pcmanfm, discord,
                          easyeffects, btop, user-packages{,-laptop}
  security/             → hardening-base (kernel params + sysctl), hardening-physical
                          (IOMMU, USBGuard, TB blacklist, AppArmor)
  shell/                → zsh, environment, alacritty, ssh, shell-packages
  dev/                  → git, gpg, claudecode, dev-packages
  services/             → core, privacy, keyd-internal-kbd
  nix/                  → nix-settings, overlays, allow-unfree, allowed-unfree.data.nix
  server/               → homeserver modules (services, watchdog, networking, users, secrets…)
secrets/                → Encrypted secrets (*.age) and secrets.nix key mapping
scripts/                → install.sh (disko), nix-commit.zsh, libreboot-build-shell.nix
```
Modules are auto-discovered: `flake.nix` imports every `*.nix` under `modules/` **except** `*.data.nix`, which is the escape hatch for plain expressions that are not modules (see `modules/gui/bemenu-style.data.nix`, `modules/nix/allowed-unfree.data.nix`).

## Conventions
- Nix files use 2‑space indentation.
- Username is set per host in `modules/computers/<host>.nix` (`nixos.configurations.<host>.username`) and passed via `specialArgs`. `nidhoggr` and `homeserver` hardcode theirs; `kuraokami` reads `inputs.identity.usernames.kuraokami` from the private identity flake (see below). No `/etc/identity.nix`, no `--impure` flag.
- Unstable packages are accessed as `pkgs.unstable.<name>` where needed.
- Avoid hardcoding usernames in module bodies.
- Prefer placing new configuration in the appropriate `modules/<domain>/` bucket and importing it from `modules/computers/<host>.nix`; `hosts/<host>/` holds only hardware-configuration and disko.

## Adding Packages
- System (both hosts): `modules/base/system-packages-baseline.nix`
- System (laptop only): `modules/base/system-packages-laptop.nix`
- Desktop/GUI utilities: `modules/gui/gui-packages.nix`
- User programs: `modules/programs/user-packages.nix` (kuraokami) / `user-packages-laptop.nix` (nidhoggr)
- Shell tools: `modules/shell/shell-packages.nix`
- Dev + security tools: `modules/dev/dev-packages.nix`
- Unfree allowlist: `modules/nix/allowed-unfree.data.nix` (consumed by `modules/nix/allow-unfree.nix`)

## Discord (2026-09-16)

`modules/programs/discord.nix` installs the **official** `pkgs.discord`, imported by `modules/computers/desktop-profile.nix` so it lands on both `kuraokami` and `nidhoggr`. This replaced Vesktop at the user's explicit instruction; `modules/programs/vesktop.nix` was deleted. **Do not propose switching back.** The tradeoffs were raised and rejected, so re-litigating them is noise: Vesktop's advantages were PipeWire screenshare-with-audio, immunity to Discord's server-side "Update Required" wall, and a declarative `programs.vesktop` home-manager module carrying a Vencord plugin set. None of that applies now.

Consequences of the swap:
- `discord` is unfree and is in `allowed-unfree.data.nix`. Its `pname` is exactly `discord`, which is what `lib.getName` feeds the `allowUnfreePredicate`.
- There is no home-manager module for discord, so **nothing here is declarative**: config lives in `~/.config/discord`, written by the app.
- It runs on Wayland rather than XWayland because `NIXOS_OZONE_WL = "1"` is set session-wide in `modules/gui/sway-system.nix`.
- The waybar `sway/workspaces` `window-rewrite` rule `"class<discord>"` in `modules/gui/waybar.nix` is correct again. It was dead under Vesktop, whose WM class is `Vesktop`, so the icon had been falling through to `window-rewrite-default`.
- If Discord force-obsoletes the pinned version, the fix is a nixpkgs bump (`nix flake update`), not an in-app update; the store path is immutable.

## Laptop software minimalism (nidhoggr, 2026-09-06)

`nidhoggr` is deliberately kept lean; the system closure was 41.8 GiB before this pass. When adding anything here, price it first (`nix path-info -S`) and prefer the smaller option. What was removed and why:

| Removed | Was | Why |
|---|---|---|
| `texliveFull` | 6.3 GB | full TeX distribution. `lyx` is still installed but **has no TeX backend and will not typeset**; either add a `texliveSmall`-class scheme or drop lyx |
| `kdenlive` / `teams-for-linux` / `rustdesk-flutter` / `feishin` / `mangohud` | ~10 GB | unused, or duplicated by something lighter. `termsonic` is now the only Subsonic client |
| `thunar` + `tumbler` + `xfconf` + `thunar-volman` | ~2.4 GB | replaced by `pcmanfm` (~310 MB), `modules/programs/pcmanfm.nix`. `gvfs` stays: GTK file managers mount removable media through it, and dropping it costs USB automount and the GUI trash backend |
| `openrazer` + `polychromatic` | | kuraokami only. No Razer hardware is ever used on nidhoggr, so its USBGuard `allow id 1532:00bf` rule and the `Razer_DeathAdder_V4_Pro` input block in `sway-host.nix` were removed too. The waybar `custom/mouse` module stays but needed a third battery source to work at all here (see "Mouse battery" below); the openrazer branch of `mouse_battery.sh` is dead on nidhoggr and must stay for kuraokami |
| `fwupd` | | Libreboot has no UEFI capsule path, so the only updatable device it could see was the NVMe. It cost a resident daemon plus an `fwupd-refresh` LVFS request on a lockdown-mode Mullvad host. Ad hoc: `nix shell nixpkgs#fwupd -c fwupdmgr get-updates`. Its boot-time timer/service tuning was removed from `boot-optimizations.nix` in the same change, because a `timerConfig` for a non-existent unit still emits a broken timer |
| `systemd-oomd` | | `systemd.oomd.enable = false` lives in `modules/base/earlyoom.nix`. Both OOM killers were running with different trigger models (oomd kills cgroups on PSI pressure, earlyoom kills the fattest process on a free-memory threshold), making the outcome unpredictable |
| `speech-dispatcher` | 1.24 GB | `services.speechd.enable = false` in the host file. nixpkgs default-enables it; nothing here asks for it. Output-only, so the mic path is unaffected; the loss is Firefox "Read Aloud" and screen readers |

Deliberately kept after review: `easyeffects` (125 MB resident, the largest user service), `xembedsniproxy` (2.85 GB of plasma-workspace for the Java AWT tray shim), `obs-studio`, Steam, the security toolkit, and `gvfs`.

pcmanfm automount is **off by default** and is not managed declaratively; enable it under Edit > Preferences > Volume Management. The setting lands in `~/.config/pcmanfm/default/pcmanfm.conf`.

## User services hang off `sway-session.target`, never `graphical-session.target`

Every home-manager user service on `nidhoggr` (`waybar`, `waybar-output-watcher`, `swayidle`, `xembedsniproxy`, `easyeffects`) must be `WantedBy`/`PartOf`/`After` **`sway-session.target`**. `graphical-session.target` is the wrong target here: NixOS ships `nixos-fake-graphical-session.target`, which pulls `graphical-session.target` up at login well before sway runs `systemctl --user import-environment`, so anything ordered on it starts with no `WAYLAND_DISPLAY` and no `QT_PLUGIN_PATH`. `sway-session.target` is what sway starts *after* the env import.

`easyeffects` was the one service still using the stock HM wiring (`graphical-session.target`), and it SIGABRTed on **every boot** with `no Qt platform plugin could be initialized` (9 consecutive coredumps by 2026-09-15, going back to at least 2026-08-24). `Restart=on-failure`/`RestartSec=5` then brought it back once sway-session was up, so `systemctl --user status` read `active (running)` afterwards and the failure was invisible outside `coredumpctl`; the real cost was a coredump per boot and 5s of unprocessed audio at login. Fixed in `modules/programs/easyeffects-service.nix` by retargeting it. Two gotchas when overriding HM unit sections: list-valued keys in `systemd.user.services.<n>.Unit` **merge by concatenation**, so `After`/`PartOf`/`Install.WantedBy` need `lib.mkForce` or the old `graphical-session.target` hook survives alongside the new one; and the pipewire ordering (`pipewire`/`pipewire-pulse`/`wireplumber`) must stay, because without it easyeffects aborts on `No connection to PipeWire` instead. `Restart=on-failure` is kept only as a backstop for a genuine pipewire restart, not as the startup path.

## Journal size cap (`modules/services/core.nix`)

`services.journald.extraConfig` sets `SystemMaxUse=512M`, `SystemMaxFileSize=64M`, `MaxRetentionSec=1month`. Journald's default cap is 10% of the filesystem, i.e. ~23G on the 234G root; it had reached 2.1G by 2026-09-15 (vacuumed to 235M on the first rebuild after the cap). The bulk of the volume is the NVMe's correctable PCIe AER chatter: the WD PC SN720 at `0000:07:00.0`, behind root port `0000:00:1d.2`, logs ~1000 `Correctable ... Physical Layer, (Receiver ID) ... RxErr` retries per boot, bursty under I/O load. Those are link-layer retries with no data risk. **Do not silence them with `pci=noaer` or `pcie_ports=compat`**: AER reporting is deliberately left on because the AX210 resume failure (see `docs/power.md`) is detected as a *fatal* AER event, and blanket-disabling AER would hide it. Cap the journal, not the source.

`sleep-actions.service` is the single unit behind both sleep hooks: its `ExecStart` runs `powerManagement.powerDownCommands` (`Before=sleep.target`) and its `ExecStop` runs `powerManagement.resumeCommands` (via `RemainAfterExit` + `StopWhenUnneeded`). It used to fail on **every resume** (fixed in 8514037): `set -e` aborted the script when `v=$(cat "$devdir/idVendor")` hit a USB interface directory that has no `idVendor`, so the backlight redraw and the waybar resume signal never ran. Two constraints follow for anything added to either hook. The generated script runs under `set -e`, so every command that can fail needs `|| true` or a guard. The unit's `PATH` holds only coreutils, findutils, gnugrep, gnused, and systemd; anything else (`pkill`, `modprobe`) must be referenced by absolute store path, e.g. `${pkgs.kmod}/bin/modprobe`.

## Battery runtime estimation (`modules/power/battery-model.nix`, nidhoggr)

`battery-model.service` learns power draw per conditioned state and solves for ETA instead of dividing charge by instantaneous current draw (the old approach swung between ~2h and ~11h on the same session). `pkgs.writers.writePython3Bin` flake8-checks the script at build time, so a typo fails the rebuild, not the service. `battery-model report` shows per-horizon accuracy against the naive estimator it replaced; use it before tuning anything.
Full design (conditioning hierarchy, calibration, storage, waybar relay contract): **docs/battery-model.md**.

## Mouse battery (waybar `custom/mouse`)

`modules/gui/waybar/scripts/mouse_battery.sh` has three sources, tried cheapest first: openrazer sysfs (`/sys/bus/hid/drivers/razermouse/*/charge_level`, kuraokami's DeathAdder V4 Pro), `/sys/class/power_supply/hidpp_battery_0` (any receiver the kernel's `hid-logitech-hidpp` binds), and `solaar show` over hidraw.

The third source exists because **the kernel cannot read nidhoggr's mouse at all**. The G502 X Lightspeed's receiver is `046d:c547`, and neither `hid-logitech-dj` nor `hid-logitech-hidpp` lists that id in its HID id table (dj tops out at `c543` in the lightspeed/nano range; check with `modinfo -F alias .../hid-logitech-dj.ko.xz`). It therefore binds `hid-generic`, no HID++ transport is set up, and no `hidpp_battery_0` power-supply node is ever created; the module printed `MSE --%` forever. Do not go looking for a missing kernel module or a udev bind rule: there is no in-tree driver for this receiver. (Writing the id to `logitech-dj/new_id` binds with `driver_data = 0`, i.e. Unifying quirks on a lightspeed receiver; not a fix.)

`modules/hardware/logitech.nix` (nidhoggr only) installs `pkgs.logitech-udev-rules` and `pkgs.solaar`. solaar speaks HID++ from userspace and does know this receiver (`logitech_receiver/base_usb.py`: `LIGHTSPEED_RECEIVER_C547`). The udev rules tag `046d` hidraw nodes `uaccess`, giving the seated user an ACL; `/dev/hidraw*` is root-only `0600` otherwise, so **after adding the rules the receiver must be replugged** (or `udevadm trigger`-ed) before it works, since uaccess is applied on device add. Upstream's `hardware.logitech.wireless.enable` is deliberately not used: it also pulls in `ltunify`, which is Unifying-only and cannot talk to this receiver either. `enableGraphical` is what installs solaar there, which is a misleading name for a CLI dependency.

Cost: each solaar call forks python+GTK for ~3.5s wall / ~1.2s CPU, and narrowing it (`solaar show 1`, `solaar show 'G502 X LS'`) saves nothing since the cost is import, not I/O. So the laptop polls at `interval = 300` rather than 60, and `signal = 13` covers the one moment the value goes stale early: `resumeCommands` in `modules/power/power-suspend.nix` re-authorizes the receiver on the USB bus (a remove+add), then backgrounds `sleep 5; pkill --signal 47 waybar` (47 = SIGRTMIN+13) to refresh it once the ACL is back. Note signal 9 / `--signal 43`, also sent on resume, belongs to `custom/vpn`.

Charging detection parses solaar's `Battery: NN%, BatteryStatus.DISCHARGING.` line; only `RECHARGING`/`SLOW_RECHARGE` count as on-charge (`ALMOST_FULL`/`FULL` are reported while discharging too).

## Minecraft (Prism Launcher, nidhoggr)

Prism is installed via `modules/programs/user-packages-laptop.nix` with the `jdks` list overridden to `[ jdk21 jdk25 jdk17 jdk8 ]` so Prism's `AutomaticJava` picks the LTS on any MC version that accepts both. Nixpkgs' `prismlauncher` wrapper already puts wayland-patched GLFW (`glfw3-minecraft`) and `gamemode.lib` into the game's `LD_LIBRARY_PATH` by default, and exposes all bundled JDKs via `PRISMLAUNCHER_JAVA_PATHS`; there is no `withWaylandGLFW` argument (common misconception).

Per-instance perf is toggled in `~/.local/share/PrismLauncher/instances/<name>/instance.cfg`, not in nix. The switches worth setting for laptop iGPU performance:

| Field | Purpose |
|---|---|
| `OverridePerformance=true` | Gate; the three below are ignored without it |
| `UseNativeGLFW=true` | LWJGL loads system GLFW (wayland-patched) instead of the bundled X11 one |
| `EnableFeralGamemode=true` | Prism launches java under `gamemoderun` (requires `programs.gamemode.enable`, which is on via `modules/programs/gaming.nix`) |
| ~~`EnableMangoHud=true`~~ | **Do not set on nidhoggr.** `mangohud` was removed 2026-09-06; the option shells out to a binary that no longer exists |
| `OverrideJavaLocation=false` | Let Prism auto-pick from `PRISMLAUNCHER_JAVA_PATHS` instead of pinning a store path that dies at GC |
| `OverrideJavaArgs=true` + `JvmArgs=…` | For Fabric on a 4G heap use Aikar's G1 flags without `-Xms/-Xmx` (Prism supplies those from `MinMemAlloc`/`MaxMemAlloc`); avoid `-Dfml.*` (Forge-only), avoid `ParallelGCThreads > CPU threads` |

Edit `instance.cfg` only when Prism is closed; the app rewrites it on quit.

## Libreboot Custom Build (nidhoggr / T480)

The T480 (`nidhoggr`) runs a custom Libreboot build, not a stock upstream ROM. Base is **Libreboot 26.01** (`git tag 26.01`) with the following changes applied as `0001-t480-personal-customizations.patch` in `~/libreboot/lbmk/`:

| Change | File(s) | Detail |
|--------|---------|--------|
| Hyperthreading | `config/coreboot/t480_vfsp_16mb/config/libgfxinit_{corebootfb,txtmode}` | `CONFIG_FSP_HYPERTHREADING=y`, 8 threads on i5-8350U; disabled upstream for Spectre/Meltdown mitigation |
| Fn/Ctrl swap | same configs | `CONFIG_H8_FN_CTRL_SWAP=y`, EC-level swap, affects all OSes including GRUB |
| SMBIOS product name | same configs | `CONFIG_MAINBOARD_SMBIOS_PRODUCT_NAME="ThinkPad T480"`, was `"T480"`; required for TLP 1.8+ Libreboot detection path to work (battery thresholds) |
| GRUB+SeaBIOS payload | `config/coreboot/t480_vfsp_16mb/target.cfg` | `payload_grubsea="y"` replaces `payload_seabios="y"`; GRUB is primary, SeaBIOS available as `seabios.elf` from GRUB menu |
| Zero boot timeout | `config/grub/xhci_nvme/config/payload` | `set timeout=0`, instant boot, no menu delay |
| FnLock default OFF | `config/coreboot/default/patches/0052-ec-h8-default-f1_to_f12_as_primary-to-0-hotkeys-primary.patch` (applied as commit in `src/coreboot/default/`) | `get_uint_option("f1_to_f12_as_primary", 0)`: CMOS does not persist this on T480/Libreboot so the fallback was always 1 (FnLock ON); changed to 0 (multimedia hotkeys primary) |

**Hardware context:**
- Flash: Winbond W25Q128.V (16MB SPI NOR)
- Programmer: Raspberry Pi Pico H running `serprog_pico.uf2`
- Prerequisite BIOS before flashing: Lenovo `n24ur39w` (v1.52) for correct EC firmware (v1.22)
- Thunderbolt firmware updated via Lenovo Vantage prior to first flash
- Internal re-flash after initial install requires `iomem=relaxed` kernel param

**Build environment:** NixOS `buildFHSUserEnv` nix-shell (`shell.nix` in `~/libreboot/lbmk/`).


## Neovim (nixvim)

`modules/programs/neovim.nix` declares the nixvim config; the Lua body lives in `modules/programs/neovim/init.lua` and is pulled in via `extraConfigLua`. The only LSP server is `typos_lsp`. Note that `nvim-lspconfig/lsp/typos_lsp.lua` sets **no `filetypes`**, and in nvim 0.12 a config without `filetypes` attaches to *every* buffer whose `buftype` is `''` or `help` (`vim/lsp.lua` `lsp_enable_callback`), so it is live in every file you open, not just code.

That broad attach surface made it hit an upstream incremental-sync bug: `vim/lsp/sync.lua:136` `assert(prev_lines[firstline])` fails whenever changetracking's cached line snapshot (`state.lines` in `vim/lsp/_changetracking.lua`) is shorter than the buffer, throwing `Error executing lua callback: .../sync.lua:136: assertion failed!` out of `compute_start_range` (neovim#33224, #24972; same class as the `compute_end_range` assert). It is a Neovim bug, not a config bug, and it usually trips when something rewrites buffer lines programmatically. Mitigation in place: `extraOptions.flags.allow_incremental_sync = false` on the server, which makes `_changetracking.get_group` downgrade Incremental to Full sync so `compute_diff` is never called. Cost is a full-buffer `didChange` per 150ms debounce window, negligible for a spell checker. Drop the flag once the upstream assert is fixed.

`render-markdown-nvim` (from `unstable.vimPlugins`, `extraPlugins` in `neovim.nix`) hits a second, unrelated core Neovim bug in the same family: `vim/treesitter/query.lua:839` `_match_predicates` throws `Index out of bounds` out of `vim/treesitter.lua:216`, surfaced through render-markdown's own `view.lua`/`ui.lua` parse pipeline (not through `nvim-treesitter`, and not the `query_predicates.lua` bug plugin issues #647/#663 describe). This is `neovim/neovim#38303`, open and unfixed upstream as of 2026-09-22, no known repro; it is a boundary-check race between the treesitter query iterator and a buffer mutation that lands inside the debounce window. Cosmetic only, it prints an error but does not crash Neovim or corrupt the buffer. `render_markdown.setup({ debounce = 200 })` in `init.lua` widens that window (default is 100ms) to make the race less frequent; there is no real fix available at the plugin-config level. Drop the override once the upstream issue is fixed.

## Doc maintenance
- Update `CLAUDE.md` (and the relevant `docs/<domain>.md`, if one exists for that area) when a change would leave a future reader confused without it: new non-obvious behavior, a design tradeoff, a gotcha. Small/self-evident diffs (typo fixes, dead code removal, a package bump) don't need a doc touch.
- New forensic detail (incident timelines, failed alternatives, root-cause investigations) belongs in `docs/<domain>.md`, not inline as a multi-paragraph comment. Inline comments stay short: the current load-bearing fact plus a pointer.
- Keep summaries precise and concrete (paths, commands, ports, services, modules). When you see drift between docs and code, fix the doc.
