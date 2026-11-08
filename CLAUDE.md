# CLAUDE.md

Guidance for working on this NixOS configuration repository. This file is a high‑signal, low‑ambiguity map for AI agents; keep it current.

This is a map of the current configuration, not a permanent feature specification. Historical rationale records what was chosen at the time; it is context, not a veto. When asked to review or simplify, verify what is active and needed now instead of treating prior additions, removals, or comments as proof of current intent.

## Overview
This is a personal NixOS flake for the host `kuraokami` (desktop) and `nidhoggr` (ThinkPad T480 laptop) with home‑manager, agenix, NUR, and nixvim, plus a headless `homeserver` host in `hosts/homeserver`. It uses Sway (Wayland), low‑latency PipeWire (+ JACK on kuraokami only), LACT for AMD GPU control (desktop), ananicy + irqbalance for CPU scheduling on both hosts (`scx_lavd` is desktop‑only; `nidhoggr.nix` does `services.scx.enable = lib.mkForce false`), a `performance` CPU governor (desktop), Mullvad VPN (sole VPN provider, lockdown mode on nidhoggr), and a privacy‑tuned desktop. Both hosts run the stock nixpkgs kernel (`pkgs.linuxPackages`, set explicitly in `modules/boot/boot-t480.nix` and implicit via default in `modules/boot/boot-amd.nix`); no CachyOS kernel is wired up despite earlier docs claiming otherwise. Laptop power uses aggressive TLP battery profiles, AC‑aware swayidle, and a waybar power-mode indicator (`set-cpu-mode {spd|bal|lap|sil|god|auto}`, sticky via `/var/lib/cpu-mode/state`). Laptop NetworkManager randomizes the MAC on every wifi/ethernet connection. Desktop theming (`modules/gui/theme.nix`) is a pitch-black OLED palette mirrored into a Qt6 palette for Qt6/Chromium-based apps, with a runtime light mode on top (`set-theme-mode`, `modules/gui/theme-mode.nix`, waybar `custom/thememode`; see `docs/gui.md`). `profile-sync-daemon` is in `services-core`, i.e. `desktop-base`, so it runs on both desktop hosts, not just the laptop. `allowedUnfree`, `allowUnfreePredicate`, `specialArgs` and `nixosConfigurations` are all defined in `modules/_plumbing/nixos.nix`, not in `flake.nix`, which holds only the flake inputs and the module auto-discovery. Primary entrypoints: `flake.nix` and `hosts/<host>/hardware-configuration.nix`.

### `docs/` — read before touching these domains
Deep forensic detail (incident timelines, root-cause investigations, declined alternatives) lives in `docs/<domain>.md`, not inline in module comments. Inline comments carry a short load-bearing fact plus a pointer to the relevant doc section. **Before making a non-trivial change to a domain listed below, read its doc first** — the doc is the actual history, the module comment is only a breadcrumb.

- `docs/power.md` — AX210 resume-from-S3 failures and mitigations, battery threshold drift/boot-race, why the `sil` fan pin needs a re-pin loop plus a `.path` unit. Relevant: `modules/power/power-suspend.nix`, `modules/power/tlp.nix`, `modules/boot/boot-t480.nix`, `modules/power/fan-silence.nix`.
- `docs/networking.md` — Mullvad dispatcher/relink rewrite history (SIGPIPE bug, stale-cache disconnect incident, lockdown mode). Relevant: `modules/networking/network-laptop.nix`.
- `docs/i915.md` — the two distinct display failures that share the sway `Atomic commit failed: Device or resource busy` signature: the 2026-11-01 GuC crash (GPU reset → `GL_CONTEXT_LOST` → desktop never repaints) and the 2026-07 S3 resume degradation. Relevant: `modules/boot/boot-t480.nix`.
- `docs/gui.md` — Qt palette investigation (why chrome can't be both pure-black and show a visible active tab), done against Helium before it was removed (2026-10-24, flake-input reduction). Relevant: `modules/gui/theme.nix`.
- `docs/trackpad-tm3471.md` — aftermarket Synaptics trackpad bring-up (coreboot + kernel + libinput). Relevant: `modules/hardware/trackpad-synaptics.nix`, `modules/gui/sway-host.nix`.
- `docs/battery-model.md` — how the adaptive battery runtime estimator works (conditioning, calibration, storage). Relevant: `modules/power/battery-model.nix`, `modules/power/scripts/battery_model.py`.
- `docs/rust-cache.md` — why `CARGO_INCREMENTAL=0` is set, the measured 0.00% sccache Rust hit rate that caused it, and why `target/` dirs cannot be capped the way sccache can. Relevant: `modules/dev/rust.nix`.
- `docs/terminal.md`: why Kitty over Foot (Kitty graphics protocol for drawing mpv `--vo=kitty` into a sub-rect) and the minimal UI configuration. Relevant: `modules/shell/kitty.nix`, `modules/gui/sway-base.nix`.

Other systems with real design depth but no incident history stay inline or in the sections below: waybar airgap toggle (`modules/gui/waybar/scripts/airgap_{mode,toggle}.sh`), USBGuard block-by-default + Mod+Shift+U manual allow flow plus an automatic `usbguard-auth-popup` zenity/sudo-gated allow popup (both session-only; `modules/security/hardening-physical.nix`, `modules/gui/waybar/scripts/usb_auth_popup.sh`), bluetooth toggle (`modules/hardware/bluetooth.nix`).

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
- `nix-commit` (Zsh function; body in `scripts/nix-commit.zsh`, loaded via the 3-line shim `modules/shell/zsh/nix-commit.zsh` that `modules/shell/zsh.nix` inlines) stages changes, rebuilds, commits with the new generation, and pushes on success. Both consumers `source` it by runtime `$HOME` path rather than store path, so `nix-commit` and `nix-upd` silently vanish if the checkout isn't at `~/nix-config`.

## Secrets (Agenix)
- Mapping file: `secrets/secrets.nix` (which keys can decrypt which secrets).
- Encrypted secrets: `secrets/*.age` (e.g., `ssh-git.age`, `ssh-github.age`, `nas-credentials.age`, `user-password.age`).
- Identity path: `/etc/age/key.txt` (provided by the user; wired in `modules/base/secrets.nix`).

The system uses agenix; do not commit plaintext secrets.

Two SSH keys, split by purpose: `ssh-git.age` → `/run/agenix/ssh-git` is the homeserver login key (laptop/desktop → homeserver; the matching pubkey is in `modules/server/users.nix` `authorizedKeys` and is materialized locally at `~/.ssh/id_ed25519_homeserver.pub`), and `ssh-github.age` → `/run/agenix/ssh-github` is the git forge key for `github.com` (pubkey at `~/.ssh/id_ed25519_github.pub`). Both are declared in `modules/base/secrets.nix` and routed in `modules/shell/ssh.nix`; the homeserver gets `ssh-github` symlinked to `~/.ssh/id_github` by `modules/server/git.nix` so it can pull the flake. `agenix` is not installed as a CLI; to add or rotate a secret, add the filename to `secrets/secrets.nix` and encrypt directly with `age -r <recipient-from-secrets.nix> -o secrets/<name>.age <plaintext>` (all three hosts share the one age recipient, so a single `-r` matches what agenix would emit). New `.age` files must be `git add`-ed before the flake can see them.

GitHub is the only forge. The repo lives at `github.com/nuclearcanopy/nix-config`, the remote is named `github`, and there is no second remote; `nix-commit`/`nix-clone` push and pull `github main`.

**A second, unrelated line existed at `github.com/eternitydebrief/nix-config` and was merged in on 2026-11-08.** The two repos had **no common ancestor** (765 vs 910 commits, empty `git merge-base`) despite configuring the same three hosts: kuraokami pushed to eternitydebrief, nidhoggr to nuclearcanopy, and they drifted for months. The root cause of the split is worth knowing because it recurs: `flake.nix` reads eval-time usernames from the **private** `nuclearcanopy/identity` flake, and kuraokami's ssh key authenticates as `eternitydebrief`, so that host literally could not evaluate this config (`Repository not found`) and had nowhere to push. If a host starts a parallel history again, check identity-repo access first. The merge took nuclearcanopy as the base and ported the other line's kuraokami/homeserver work on top; nothing from eternitydebrief's history is in this one, so that repo is the only record of those 765 commits — do not delete it.

## Private identity flake (eval-time values)
Agenix decrypts at **activation** time, which is far too late for anything the Nix **evaluator** needs: `username` feeds `users.users.<name>`, home-manager paths, and agenix's own `owner =`. A username therefore cannot be an agenix secret; there is no version of that which works. Values in that class live in a separate private flake, `git+ssh://git@github.com/nuclearcanopy/identity.git`, wired as the `identity` input in `flake.nix`. Consequences: **read access to that repo is required to evaluate this flake at all** (a missing key surfaces as a git fetch error, not a Nix error), `flake.lock` pins its rev and URL but never its contents, and the fetched source does land world-readable in `/nix/store` on the machine itself, so this hides the value from the public repo, not from a local user. To rotate or add a value, commit to the identity repo and run `nix flake lock --update-input identity`.

It holds two attrs: `usernames.<host>` (just `kuraokami`, since `nidhoggr`/`loki` and `homeserver`/`homeserver` are already public) and `location` (`timeZone` + `extraLocaleSettings`, read in `modules/computers/kuraokami.nix`, `nidhoggr.nix`, and `homeserver.nix`; previously hardcoded as plain strings directly in `host-base.nix`/`server/system.nix`, which leaked country/region in the public repo).

Homeserver secrets are wired in `modules/server/secrets.nix`: `homeserver-user-password.age`, `homeserver-navidrome-env.age`, `homeserver-cloudflared-credentials.age`, `homeserver-cloudflared-config.age` (the tunnel's `config.yml` mount; the tunnel cannot start without it), and `homeserver-mscd-api-hash.age`. The retired SearXNG secret is no longer declared; its encrypted file and recipient mapping are retained but inactive.

The homeserver declares only its own secrets plus the two it consumes from the shared desktop set (`ssh-github` and `nas-credentials`); it does not import `modules/base/secrets.nix`.

## Homeserver streaming reliability (`modules/server/services.nix`)
Navidrome is configured for resilient Subsonic streaming: 5GB transcoding cache, 500MB image cache, opus default downsampling, 6h scan schedule, 168h sessions, downloads enabled, scan log lines remain at `info` level (the boost sidecar trigger needs them). The container's `environmentFiles` list reads `homeserver-navidrome-env.age` AND a local mode-600 file at `/var/lib/navidrome/lastfm.env` (the latter wins per docker env-file "last duplicate key wins"; it lets us rotate the Last.fm API key on-host without re-encrypting the agenix secret, which is only decryptable from `kuraokami`). `docker-navidrome.service` has `Restart=always` with 5s backoff.

A sidecar systemd unit `navidrome-boost.service` (defined in the same file) tails the Navidrome container's journal for `Streaming file` / `GET /rest/stream` / `GET /rest/download` / `Scanner` lines and flips the CPU scaling governor between `powersave` (idle) and `performance` (active), with a 120s idle drop watchdog. State lives at `/run/navidrome-boost/last-activity`. This was added to keep the i5-5200U responsive under transcoding load without globally pinning the governor to performance.

**mscd download-archive commit gate (`modules/server/scripts/mscd.zsh`).** `--download-archive` must never point at the real archive. yt-dlp records a video ID as soon as extraction finishes, i.e. *before* `mscd` tags the file and copies it into the library, so any failure in between (a crashed `write_metadata`, an unwritable dest, a dropped NAS mount) left tracks marked "already downloaded" with nothing on disk — and because the archive is read on the next run, every retry became a silent no-op that still reported success. Only `--force` escaped it. Observed 2026-10-31 on Bosquito/Babylon: all 14 IDs archived, zero files anywhere. The archive is now **two-phase**: yt-dlp writes to a scratch copy (`mscd_archive_stage`), and new IDs are folded into the real archive only after `mscd_verify_imported` confirms each file exists, is non-empty and carries artist+album tags (`mscd_archive_commit`); a failed import discards the scratch copy (`mscd_archive_discard`, which logs how many IDs it dropped) so a plain retry re-downloads. If you touch this, keep the invariant: **nothing may enter `mscd_archive.txt` until the file it refers to is verified in the library.** Note `write_metadata`'s Python still swallows per-file exceptions and exits 0, so its status is checked but cannot be trusted alone — `mscd_verify_imported` is the actual gate, which is why it re-reads tags off the library copy rather than believing the tagger.

`mscd_api.py` passes the user-supplied URL to zsh as a positional `$1`, never interpolated into the script body: zsh performs command substitution inside double quotes, so an interpolated `"https://youtube.com/$(...)"` previously ran arbitrary shell as the `homeserver` user. Tightening `is_valid_url` is **not** the fix (it only requires the host as a substring, and quote-breaking works too). yt-dlp comes from `unstable.yt-dlp` in `modules/server/system.nix` rather than self-updating from GitHub at download time.

The `cloudflared` container runs with `--protocol quic --ha-connections 4`. Defaults (HTTP/2, single connection) were a streaming bottleneck that manifested as Subsonic skips and "song unavailable" errors. It also runs `--metrics 0.0.0.0:44483` and publishes that port to `127.0.0.1:44483` so the watchdog can poll `/ready` (200 = ≥1 tunnel connection up).

## Homeserver failsafes (`modules/server/watchdog.nix`)
The homeserver runs on aging laptop hardware and cuts out often, so `server-watchdog` (module `nixos.modules.server-watchdog`, imported in `modules/computers/homeserver.nix`) is a crash/hang recovery layer on top of the hard-failure defenses already in `server-system` (hardware watchdog `RuntimeWatchdogSec=60s`, `panic_on_oops=1`, `kernel.panic=30`, daily 05:00 reboot). It:
- Forces `Restart=always` (`RestartSec=5s`, `StartLimitIntervalSec=0`, `StartLimitBurst=0`) on the docker daemon and on every container unit. The disabled start-limit is deliberate — the systemd default (5-in-10s) would mark a fast-flapping container as failed and leave it down, defeating `Restart=always`. `filebrowser` gets a gentler `RestartSec=30s` (see the NAS note below).
- Enables `services.earlyoom` (freeMem 5%, freeSwap 10%, notifications off since headless) to kill the fattest process before the kernel OOM-killer hard-locks the box.
- Runs `server-watchdog.timer` every 2 min (`OnBootSec=3min`, `OnUnitActiveSec=2min`) executing `modules/server/scripts/healthcheck.sh`.
- Runs `net-watchdog.timer` every 1 min (`OnBootSec=2min`) executing `modules/server/scripts/net-watchdog.sh`.
- `reboot-log.service` runs once at multi-user.target and appends the previous boot's shutdown cause (systemd reboot vs. panic vs. watchdog vs. OOM), last kernel-log tail, and last watchdog activity to `/var/log/reboot-history.log`. Persistent (ext4) so it survives reboots and gives a paper trail for post-mortem.

The health-check script runs `timeout 20 docker ps` plus curls navidrome `:4533/`, filebrowser `:8081/health`, portainer `:9000/api/status`, cloudflared `:44483/ready`, and mscd-api `:8090/health`. Escalation ladder per target (checks ~2 min apart): **1 fail** → restart just that container unit; **≥2 fails** → bounce the whole docker stack (`docker.service` + `init-docker-network.service` + all container units); **≥6 fails** → `systemctl reboot`. The docker-daemon check is first and hardest: if `docker ps` times out (20s), it restarts `docker.service` immediately and reboots after 6 consecutive wedges. Failure counters live in `/run/server-watchdog` (tmpfs) on purpose so a reboot always starts from a clean slate and a permanently-broken service can never turn into a boot loop.

**Dependency prechecks** short-circuit that ladder for services whose health hinges on an external prereq a restart cannot fix. `check` takes an optional 4th arg (`egress` | `nas` | `svc`):
- `filebrowser` is `nas`: it bind-mounts `/mnt/nas/filebrowser` and exits 125 on every start when the NAS is unreachable, and **a reboot cannot remount a NAS**. On a dead NAS the healthcheck skips the restart and does **not** increment the failcount, so it never climbs to a stack bounce or reboot. `nas_alive()` probes with `timeout 6 ls /mnt/nas` (autofs always looks mounted even when the CIFS backend is dead — only a readability probe is reliable). This fixed a ~15-min reboot loop (2026-08-23).
- `cloudflared` is `egress`. If `/ready` fails **and** external egress is also dead, it skips entirely — restarting during a Mullvad/WiFi flap only extends downtime; `net-watchdog` owns the transport. But if `/ready` fails while egress is **alive**, the ladder diverges (the 2026-09-06 fix): that signature is a flapping Mullvad relay, where a stack bounce or reboot only re-dials the same relay and loops. So: **fail 1** → container restart; **≥2 (`RECONNECT_AT`)** → `reconnect_transport()` runs `mullvad reconnect` for a fresh handshake and relay reselection (falling back to restarting `mullvad-daemon`) then restarts the container; **≥6** → reboot as last resort. Needs the `mullvad` CLI on the unit's PATH (`pkgs.mullvad` in `watchdog.nix`). Reproducible by hand as `mullvad reconnect && docker restart cloudflared`.
- `mscd-api` is `svc` (a plain systemd service, not a container): a failed probe restarts just that unit and never bounces the docker stack or climbs toward a reboot.

To add a monitored service, append a `check <name> <url> <unit> [egress|nas|svc]` line; for a container also add the unit to `CONTAINERS`.

`net-watchdog.sh` tries HTTPS egress to 1.1.1.1 and 8.8.8.8. Ladder (~1 min apart): **1-2 fails** → log only; **≥3** → restart `mullvad-daemon`; **≥5** → restart `NetworkManager`; **≥10** → reboot. Counters in `/run/net-watchdog`. This exists because the transport stack (WiFi → Mullvad WG lockdown → cloudflared QUIC) fails as a unit: a Mullvad handshake stall drops all 4 cloudflared HA connections at once with `timeout: no recent network activity`, and no container-level restart fixes that.

See also `modules/server/observability.nix` (`nixos.modules.server-observability`, imported in `modules/computers/homeserver.nix`) for the heavy logging layer: persistent journal capped at 20G with rate-limiting disabled, auditd watches on `/etc/nixos` and `/var/lib/navidrome`, NetworkManager/Mullvad/docker debug logging, and `smartd` with hourly `smart-log.service` appending to `/var/log/smart-health.log`. The `execve` audit rule and `/var/lib/docker` watch were removed 2026-08-23: together they were ~91% of journal volume for near-zero forensic value.

## kuraokami hardware fault (2026-11-08) — read before debugging a crash
kuraokami hard-reset on 2026-11-08 00:00 with a **Data Fabric sync flood**, i.e. the CPU force-reset the platform on an uncorrected error. The next boot read it back out of the sticky registers:

```
x86/amd: Previous system reset reason [0x08000800]: an uncorrected error caused a data fabric sync flood event
mce: [Hardware Error]: CPU 0:  Bank 27 baa000000000080b   (SMCA_PIE, "Hardware Assert", PCC=1 TCC=1)
mce: [Hardware Error]: CPU 10: Bank 0  bc00080001010135   (SMCA_LS_V2, uncorrected poison, addr 0x13a0ff200)
```

The **identical** Bank 0 status word appeared on 2026-10-30 from CPU 22 (survivable then: `Sending SIGBUS to nix:36597`). **CPU 10 and CPU 22 are SMT siblings of one physical core (core_id 12, CCD1)** — one core, two uncorrected cache errors nine days apart, escalating to fatal. The same crash reproduces **under Windows**, which rules out a Linux/driver cause.

Key reasoning for anyone re-opening this: the RAM is non-ECC (`Error Correction Type: None`, no `/sys/devices/system/edac/mc/`), so a DRAM bit flip **cannot** produce the logged poison bit — the error originated in on-die SRAM/fabric, i.e. the CPU, not the DIMMs. The Corsair `CMN32GX4M2Z3600C16` kit also runs at 3200, *below* its rated 3600, so this is not an aggressive memory OC. Do not chase kernel bugs: there was no panic, no Oops, no call trace, no pstore record, no coredump. Absence of a panic trace plus a sync-flood reset reason **is** the hardware signature. A PSU brownout is also ruled out, since that would leave the reset-reason register clear and no MCA records.

Board is ASUSTeK **PRIME X570-P** (EZ Flash 3 + CrashFree BIOS 3; **no** USB BIOS FlashBack, so the `BIOSRenamer.exe` in ASUS's zip is useless here). **Flashed 5031 -> 5044 on 2026-11-08** and the firmware angle is now closed:

- **Microcode did not move**: `0xa201030` both before and after 5044, i.e. that is already the latest patch for stepping `a20f10`. `hardware.cpu.amd.updateMicrocode = true` was never going to help, and neither does the BIOS. Do not re-suggest a microcode update as a fix.
- **PBO and Curve Optimizer were already entirely off** before the crash, so the "aggressive undervolt" explanation is dead: the faults happened on AMD's stock V/F curve. Note PBO off does **not** mean boost off (`cpufreq boost = 1`, max 4954 MHz) — stock Precision Boost 2 was active, which is the correct baseline for calling this a defect rather than a tuning error.

With tuning and firmware both eliminated, and memory running below rated spec on non-ECC DIMMs (which cannot generate the logged poison bit), **the remaining diagnosis is a defective CPU core**. The decisive open test is to pin load to logical CPUs 10 and 22 (core_id 12) versus a known-good core and watch `journalctl -kf | grep -i "hardware error"`; an error that reproduces preferentially on core 12 at stock voltages confirms it. A workaround short of replacement is to offline CPUs 10 and 22 (`/sys/devices/system/cpu/cpu{10,22}/online = 0`), costing one of twelve cores. `nix store verify --all` was clean over 78,311 paths on 2026-11-08, so no silent corruption resulted.

`modules/hardware/rasdaemon.nix` (`nixos.modules.rasdaemon`) exists because of this. It is wired **only into `modules/computers/kuraokami.nix`**, not `desktop-base`: nidhoggr has no such fault history. It was added after the fact, so **the two MCEs above are not in its DB**. Query future events with `ras-mc-ctl --summary` / `--errors`. Diagnostics (`smartmontools`, `nvme-cli`, `dmidecode`, `lm_sensors`) are in `system-packages-baseline` for the same reason; none were installed when this happened. NVMe is healthy (zero media errors, 15% used, 26k power-on hours).

## kuraokami ethernet: enp4s0 capped at 100baseT
The onboard Realtek RTL8168h (r8169) cannot hold a link while 1000baseT/Full is in its advertisement: the link comes up and drops carrier milliseconds later, over and over (`Link is Up - 100Mbps/Full` immediately followed by `Link is Down`, ~14s apart), leaving NM unable to ever activate the device. Note the flap happens even though the switch only advertises 10/100, i.e. 1G is never actually negotiated; merely *offering* it is enough to break the link, so "it negotiated 100Mbps, therefore the cap worked" is a false read. An EEE rule was the original fix, but the PHY now reports `EEE status: not supported`, so it was a **no-op**. `modules/computers/kuraokami.nix` caps the advertisement with `ethtool -s enp4s0 autoneg on advertise 0x00c` (100baseT half+full only), which is exactly what `ethtool -s enp4s0 speed 100` produces and the only setting observed to hold. Autoneg stays **on** deliberately: forcing `speed 100 duplex full autoneg off` also works but relies on the switch's parallel detection and risks a duplex mismatch. The script's `*1000baseT*` guard is **load-bearing**: `ethtool -s` always restarts autonegotiation, so an unguarded link-up hook would flap the link forever.

**Do not apply this from a udev `ACTION=="add"` rule.** That was the 2026-11-08 failure: r8169 attaches the PHY in its *open* path, not at probe (`attached PHY driver` lands ~2s after `renamed from eth0`), so at the add event there are no link modes to read, the `*1000baseT*` guard matches nothing, the script no-ops, and any write there would be wiped by the attach anyway. The NM dispatcher hook cannot rescue it either, because NM only emits `up` once a connection activates and a flapping link never gets there; it is a chicken-and-egg, and the box boots with no network until someone runs `ethtool` by hand. The cap now runs from `systemd.services.r8169-cap-100`, pulled in by `wantedBy = [ "sys-subsystem-net-devices-enp4s0.device" ]`: it does `ip link set enp4s0 up` itself to force the PHY attach, then polls once a second (60s cap) until the advertisement reads back capped on three consecutive reads, since the attach can reset it a beat after the write. It is intentionally **not** ordered before `NetworkManager.service` — it waits on hardware, and blocking NM on that turns a dead NIC into a slow boot. The NM dispatcher hook on `enp4s0 up` is kept as the secondary re-apply for a later driver/PHY reset. Neither trigger fires during `nixos-rebuild switch` on an already-up link, so a fresh cap only takes effect at the next boot, link event, or `systemctl start r8169-cap-100`.

## Architecture
```
flake.nix               → Flake inputs + module auto-discovery only
  _plumbing/nixos.nix   → nixosConfigurations, specialArgs, allowedUnfree, allowUnfreePredicate
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
                          fonts, xdg-portal, swayidle, theme-mode (set-theme-mode)
  hardware/             → audio (incl. audio-rt-base), graphics (amd/intel), gpu-amd (LACT),
                          cpu scheduler/governor, bluetooth, openrazer, logitech, trackpoint,
                          trackpad-synaptics, v4l2loopback, rasdaemon (kuraokami only)
  networking/           → base, network-laptop (Mullvad lockdown/relink), mullvad-*, nas-mount
  power/                → tlp, cpu-modes, thinkfan, undervolt, power-suspend, brightness-persist,
                          battery-model (+ scripts/battery_model.py), fan-silence,
                          caffeine-watchdog, fwupd (kuraokami only)
  programs/             → firefox, neovim, gaming, virtualisation, thunar, pcmanfm, discord,
                          easyeffects, btop, user-packages{,-laptop}, prism-mullvad,
                          nix-ld (kuraokami only)
  security/             → hardening-base (kernel params + sysctl), hardening-physical
                          (IOMMU, USBGuard, TB blacklist, AppArmor)
  shell/                → zsh, environment, kitty (primary terminal), ssh,
                           shell-packages
  dev/                  → git, gpg, claudecode, dev-packages
  services/             → core, privacy, keyd-internal-kbd, uptimed (+ scripts/playtime.py)
  nix/                  → nix-settings, overlays, allow-unfree, allowed-unfree.data.nix
  server/               → homeserver modules (services, watchdog, observability, networking,
                          users, secrets…)
secrets/                → Encrypted secrets (*.age) and secrets.nix key mapping
scripts/                → install.sh (disko), nix-commit.zsh, libreboot-build-shell.nix
```
Modules are auto-discovered: `flake.nix` imports every `*.nix` under `modules/` **except** `*.data.nix`, which is the escape hatch for plain expressions that are not modules. There are exactly three: `modules/nix/allowed-unfree.data.nix`, `modules/hardware/usb-ids.data.nix`, and `modules/programs/user-packages-common.data.nix`.

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
- Unfree allowlist: `modules/nix/allowed-unfree.data.nix` (imported by `modules/_plumbing/nixos.nix`, which builds the predicate and threads it through `specialArgs`; `modules/nix/allow-unfree.nix` only re-exports what it is handed)
- Packages for **both** desktop hosts: `modules/programs/user-packages-common.data.nix`, imported by both `user-packages.nix` and `user-packages-laptop.nix`. Adding a shared package to the two host files separately is the wrong move.

Three packages are **deliberately absent** from every list because a module ships a wrapper that owns the same binary name; re-adding them causes a collision at home-manager activation:
- `prismlauncher` → `modules/programs/prism-mullvad.nix`
- `stremio-linux-shell` → the `stremio` wrapper in `modules/base/home-base.nix` (also sets `FFMPEG_BIN`/`FFPROBE_BIN`, without which upstream's `server.js` spawns `undefined` and crashes on stream probing, since it ships no bundled ffmpeg and there is no `/usr/bin` fallback on NixOS)
- `bolt-launcher` → the `bolt-launcher` wrapper in the same file

## Discord (2026-09-16)

`modules/programs/discord.nix` currently installs the official `pkgs.discord` on both desktop hosts. This replaced Vesktop after the tradeoffs were reviewed at the time; the earlier decision is historical context, not a permanent restriction on future user requests.

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
| `texliveFull` | 6.3 GB | full TeX distribution, laptop-only removal in this pass. `lyx` outlived it here and could not typeset; both are now gone from **every** host (2026-10-30, the user no longer writes LaTeX at all), so don't re-add either as a dependency of the other |
| `kdenlive` / `teams-for-linux` / `rustdesk-flutter` / `feishin` / `mangohud` | ~10 GB | unused, or duplicated by something lighter. `termsonic` is now the only Subsonic client |
| `thunar` + `tumbler` + `xfconf` + `thunar-volman` | ~2.4 GB | replaced by `pcmanfm` (~310 MB), `modules/programs/pcmanfm.nix`. `gvfs` stays: GTK file managers mount removable media through it, and dropping it costs USB automount and the GUI trash backend |
| `openrazer` + `polychromatic` | | kuraokami only. No Razer hardware is ever used on nidhoggr, so its USBGuard `allow id 1532:00bf` rule and the `Razer_DeathAdder_V4_Pro` input block in `sway-host.nix` were removed too. The waybar `custom/mouse` module stays but needed a third battery source to work at all here (see "Mouse battery" below); the openrazer branch of `mouse_battery.sh` is dead on nidhoggr and must stay for kuraokami |
| `fwupd` | | **Laptop only.** Libreboot has no UEFI capsule path, so the only updatable device it could see was the NVMe. It cost a resident daemon plus an `fwupd-refresh` LVFS request on a lockdown-mode Mullvad host. Ad hoc: `nix shell nixpkgs#fwupd -c fwupdmgr get-updates`. Its boot-time timer/service tuning was removed from `boot-optimizations.nix` in the same change, because a `timerConfig` for a non-existent unit still emits a broken timer. Note `modules/power/fwupd.nix` **does** exist and is wired into `modules/computers/kuraokami.nix`, where the board/GPU/NVMe all have real capsule paths — do not promote it to `desktop-base`, that would put it back on nidhoggr |
| `systemd-oomd` | | `systemd.oomd.enable = false` lives in `modules/base/earlyoom.nix`. Both OOM killers were running with different trigger models (oomd kills cgroups on PSI pressure, earlyoom kills the fattest process on a free-memory threshold), making the outcome unpredictable |
| `speech-dispatcher` | 1.24 GB | `services.speechd.enable = false` in the host file. nixpkgs default-enables it; nothing here asks for it. Output-only, so the mic path is unaffected; the loss is Firefox "Read Aloud" and screen readers |

Previously kept after review: `easyeffects` (125 MB resident, the largest user service), `xembedsniproxy` (2.85 GB of plasma-workspace for the Java AWT tray shim), `obs-studio`, Steam, the security toolkit, and `gvfs`. Reassess these if reviewing current needs; this list is not a keep directive.

pcmanfm automount is **off by default** and is not managed declaratively; enable it under Edit > Preferences > Volume Management. The setting lands in `~/.config/pcmanfm/default/pcmanfm.conf`.

## User services hang off `sway-session.target`, never `graphical-session.target`

Every home-manager user service on `nidhoggr` (`waybar`, `waybar-output-watcher`, `swayidle`, `xembedsniproxy`, `easyeffects`) must be `WantedBy`/`PartOf`/`After` **`sway-session.target`**. `graphical-session.target` is the wrong target here: NixOS ships `nixos-fake-graphical-session.target`, which pulls `graphical-session.target` up at login well before sway runs `systemctl --user import-environment`, so anything ordered on it starts with no `WAYLAND_DISPLAY` and no `QT_PLUGIN_PATH`. `sway-session.target` is what sway starts *after* the env import.

`easyeffects` was the one service still using the stock HM wiring (`graphical-session.target`), and it SIGABRTed on **every boot** with `no Qt platform plugin could be initialized` (9 consecutive coredumps by 2026-09-15, going back to at least 2026-08-24). `Restart=on-failure`/`RestartSec=5` then brought it back once sway-session was up, so `systemctl --user status` read `active (running)` afterwards and the failure was invisible outside `coredumpctl`; the real cost was a coredump per boot and 5s of unprocessed audio at login. Fixed in `modules/programs/easyeffects-service.nix` by retargeting it. Two gotchas when overriding HM unit sections: list-valued keys in `systemd.user.services.<n>.Unit` **merge by concatenation**, so `After`/`PartOf`/`Install.WantedBy` need `lib.mkForce` or the old `graphical-session.target` hook survives alongside the new one; and the pipewire ordering (`pipewire`/`pipewire-pulse`/`wireplumber`) must stay, because without it easyeffects aborts on `No connection to PipeWire` instead. `Restart=on-failure` is kept only as a backstop for a genuine pipewire restart, not as the startup path.

## Journal size cap (`modules/services/core.nix`)

`services.journald.extraConfig` sets `SystemMaxUse=512M`, `SystemMaxFileSize=64M`, `MaxRetentionSec=1month`. Journald's default cap is 10% of the filesystem, i.e. ~23G on the 234G root; it had reached 2.1G by 2026-09-15 (vacuumed to 235M on the first rebuild after the cap). The bulk of the volume is the NVMe's correctable PCIe AER chatter: the WD PC SN720 at `0000:07:00.0`, behind root port `0000:00:1d.2`, logs ~1000 `Correctable ... Physical Layer, (Receiver ID) ... RxErr` retries per boot, bursty under I/O load. Those are link-layer retries with no data risk. **Do not silence them with `pci=noaer` or `pcie_ports=compat`**: AER reporting is deliberately left on because the AX210 resume failure (see `docs/power.md`) is detected as a *fatal* AER event, and blanket-disabling AER would hide it. Cap the journal, not the source.

`sleep-actions.service` is the single unit behind both sleep hooks: its `ExecStart` runs `powerManagement.powerDownCommands` (`Before=sleep.target`) and its `ExecStop` runs `powerManagement.resumeCommands` (via `RemainAfterExit` + `StopWhenUnneeded`). It used to fail on **every resume** (fixed in 8514037): `set -e` aborted the script when `v=$(cat "$devdir/idVendor")` hit a USB interface directory that has no `idVendor`, so the backlight redraw and the waybar resume signal never ran. Two constraints follow for anything added to either hook. The generated script runs under `set -e`, so every command that can fail needs `|| true` or a guard. The unit's `PATH` holds only coreutils, findutils, gnugrep, gnused, and systemd; anything else (`pkill`, `modprobe`) must be referenced by absolute store path, e.g. `${pkgs.kmod}/bin/modprobe`.

## Uptime accounting (`modules/services/uptimed.nix`, nidhoggr, 2026-10-28)

Two separate things, deliberately not merged. `services.uptimed.enable` gives the highest-uptime leaderboard (`uprecords`) and nothing else. `playtime` is the lifetime "how long has this machine been running" total: `playtime-tick.timer` folds elapsed `CLOCK_MONOTONIC` into `/var/lib/playtime/state.json` every 2 min (`playtime` / `playtime seconds` / `playtime tick` / `playtime waybar`). The waybar `custom/playtime` module (laptop profile only, since kuraokami doesn't import this bucket) polls `playtime waybar` every 60s through `/run/current-system/sw/bin/`, because waybar's own PATH is the home-manager session one.

uptimed cannot do the second job. Its clock is `CLOCK_BOOTTIME`, which keeps counting through S3; over the month of journal retention measured on 2026-10-28, 199.5h of 321h of session time was suspend, so its totals run ~2.6x high here. It also prunes the log to `LOG_MAXIMUM_ENTRIES=50` and drops sessions under `LOG_MINIMUM_UPTIME=1h`, and its config path is compiled in as `$out/etc/uptimed.conf` (`-DFILE_CONFIG` in the upstream `Makefile.am`), so changing either default means overriding the package.

The pre-existing total is `seedHours = 4383` in the module, written to `/etc/playtime-seed` and added at display time, not baked into the state file; edit the constant to correct it. It came from the NVMe's SMART `Power On Hours` on 2026-10-28 (WDC PC SN720, 4383h / 6178 power cycles / 607 unsafe shutdowns), which is drive lifetime and therefore predates both the install and the purchase, which is the intent. For reference, the install itself (wtmp begins 2026-05-18 21:55, never rotated) is ~2555h of boot-to-shutdown session time across 203 boots: 2184.8h from the 143 clean sessions, plus ~370h for the 59 that ended uncleanly. `last` cannot date those 59, since with no shutdown record it fills the end with the *next* boot time (one reads `7+12:04`); the 0.24 correction factor comes from comparing wtmp against journald over the window journald still covers.

## Battery runtime estimation (`modules/power/battery-model.nix`, nidhoggr)

`battery-model.service` learns power draw per conditioned state and solves for ETA instead of dividing charge by instantaneous current draw (the old approach swung between ~2h and ~11h on the same session). `pkgs.writers.writePython3Bin` flake8-checks the script at build time, so a typo fails the rebuild, not the service. `battery-model report` shows per-horizon accuracy against the naive estimator it replaced; use it before tuning anything.
Full design (conditioning hierarchy, calibration, storage, waybar relay contract): **docs/battery-model.md**.

## Caffeine-mode lid watchdog (`modules/power/caffeine-watchdog.nix`, nidhoggr)

`caffeine.sh` (`modules/gui/waybar/scripts/caffeine.sh`) toggles a `systemd-inhibit --what=idle:sleep:handle-lid-switch` process so the laptop stays up with the lid shut (agents running in a bag). That inhibitor blocks logind's lid-switch handling entirely, so there is no suspend and no event to hook a safety net off of; `caffeine-watchdog.service`/`.timer` polls every 30s instead, checking the caffeine pidfile (`/run/user/<uid>/waybar-caffeine.pid`) and `/proc/acpi/button/lid/*/state`. While both caffeine-on and lid-closed hold true it caps `/var/lib/cpu-mode/state` at `bal` (re-applied every tick, so a mode bumped back up over SSH gets re-capped), and once that combined state has held continuously for 30 minutes it calls `systemctl poweroff`. Added 2026-10-06 because caffeine mode kept getting left on with the lid closed, draining the battery to zero in a bag. State lives in `/run/caffeine-watchdog` (tmpfs) so a reboot or an open-lid/caffeine-off transition always resets the clock; there is deliberately no "restore previous mode on lid-open," since re-arming performance mode automatically would defeat the point.

## Silent fan mode (`sil`, `modules/power/fan-silence.nix`, nidhoggr)

A fifth CPU mode, `sil`, is `lap`'s power profile (powersave, 2GHz, no turbo, PL1=15W) with the fan pinned to level 0. It shows as a **red** `LAP` in waybar's `custom/thermalmode`; plain lap stays amber. Reached by **middle-clicking the indicator while already in lap**; middle-click from any other mode still means `god`, and middle-click from `sil` drops back to plain `lap`. Left/right cycling out of `sil` needs no special case, since any non-`sil` mode in the state file releases the fan.

`set-cpu-mode sil` itself only reuses the `lap` branch and writes `sil` to `/var/lib/cpu-mode/state`; it never touches the fan. All fan work is root-side in `fan-silence.nix`: `fan-silence-reconcile.path` watches that state file and runs a oneshot that starts `fan-silence.service` for `sil` and stops it plus restarts `thinkfan` otherwise. That indirection is the point, because `set-cpu-mode` runs unprivileged from waybar and cannot start or stop system units; there is no polkit rule here and none is needed. The reconcile service is also `wantedBy=graphical.target`/`After=cpu-mode-restore.service`, because `PathChanged` does not fire for an already-existing unchanged file, so boot would otherwise ignore the sticky mode.

Three things not to "simplify":
- The service **loops**, re-writing `level 0` every 2s. A single write does not hold: the EC reclaims the fan across S3 resume and thinkpad_acpi's fan watchdog expires back to auto.
- `Conflicts=thinkfan.service` is load-bearing. thinkfan owns the same tpacpi node and rewrites the level every tick, so leaving it up makes the fan pulse instead of stop. `ExecStopPost` writes `level auto` before thinkfan comes back, so a thinkfan start failure cannot strand the fan off.
- The 90C vent (level 7 for 15s) is a don't-cook-the-board backstop, not thermal policy. Under lap's 15W cap the package sits near 60C, so it should not fire in practice. Note the mode is sticky across reboot exactly like `god`.

waybar detects `sil` by `[[ -d /run/fan-silence ]]`, the service's `RuntimeDirectory`; systemd removes it on stop, so it cannot go stale, and it costs a stat rather than a `systemctl` fork on every 5s poll.

## Mouse battery (waybar `custom/mouse`)

`modules/gui/waybar/scripts/mouse_battery.sh` has three sources, tried cheapest first: openrazer sysfs (`/sys/bus/hid/drivers/razermouse/*/charge_level`, kuraokami's DeathAdder V4 Pro), `/sys/class/power_supply/hidpp_battery_0` (any receiver the kernel's `hid-logitech-hidpp` binds), and `solaar show` over hidraw.

The third source exists because **the kernel cannot read nidhoggr's mouse at all**. The G502 X Lightspeed's receiver is `046d:c547`, and neither `hid-logitech-dj` nor `hid-logitech-hidpp` lists that id in its HID id table (dj tops out at `c543` in the lightspeed/nano range; check with `modinfo -F alias .../hid-logitech-dj.ko.xz`). It therefore binds `hid-generic`, no HID++ transport is set up, and no `hidpp_battery_0` power-supply node is ever created; the module printed `MSE --%` forever. Do not go looking for a missing kernel module or a udev bind rule: there is no in-tree driver for this receiver. (Writing the id to `logitech-dj/new_id` binds with `driver_data = 0`, i.e. Unifying quirks on a lightspeed receiver; not a fix.)

`modules/hardware/logitech.nix` (nidhoggr only) installs `pkgs.logitech-udev-rules` and `pkgs.solaar`. solaar speaks HID++ from userspace and does know this receiver (`logitech_receiver/base_usb.py`: `LIGHTSPEED_RECEIVER_C547`). The udev rules tag `046d` hidraw nodes `uaccess`, giving the seated user an ACL; `/dev/hidraw*` is root-only `0600` otherwise, so **after adding the rules the receiver must be replugged** (or `udevadm trigger`-ed) before it works, since uaccess is applied on device add. Upstream's `hardware.logitech.wireless.enable` is deliberately not used: it also pulls in `ltunify`, which is Unifying-only and cannot talk to this receiver either. `enableGraphical` is what installs solaar there, which is a misleading name for a CLI dependency.

Cost: each solaar call forks python+GTK for ~3.5s wall / ~1.2s CPU, and narrowing it (`solaar show 1`, `solaar show 'G502 X LS'`) saves nothing since the cost is import, not I/O. So the laptop polls at `interval = 300` rather than 60, and `signal = 13` covers the one moment the value goes stale early: `resumeCommands` in `modules/power/power-suspend.nix` re-authorizes the receiver on the USB bus (a remove+add), then backgrounds `sleep 5; pkill --signal 47 waybar` (47 = SIGRTMIN+13) to refresh it once the ACL is back. Note signal 9 / `--signal 43`, also sent on resume, belongs to `custom/vpn`.

Charging detection parses solaar's `Battery: NN%, BatteryStatus.DISCHARGING.` line; only `RECHARGING`/`SLOW_RECHARGE` count as on-charge (`ALMOST_FULL`/`FULL` are reported while discharging too).

## Minecraft (Prism Launcher, nidhoggr)

Prism is **not** in either host's package list. It comes from the shared `modules/programs/prism-mullvad.nix` module (`config.homeManager.modules.prism-mullvad`, imported by both `kuraokami.nix` and `nidhoggr.nix`) with the `jdks` list overridden to `[ jdk21 jdk25 jdk17 jdk8 ]` so Prism's `AutomaticJava` picks the LTS on any MC version that accepts both. That module `symlinkJoin`s over `prismlauncher`, keeping its icons/desktop entry/mime data and swapping only `bin/prismlauncher` for a `mullvad-exclude` shim, so Minecraft egresses around the tunnel and servers that ban shared VPN exit IPs see the real ISP address. Because the wrapper owns the `prismlauncher` binary name, the raw package is deliberately absent from `user-packages.nix` and `user-packages-laptop.nix`; re-adding it there causes a collision. Verify the bypass with `mullvad-exclude curl -s https://api.ipify.org` (real ISP IP) vs `curl -s https://api.ipify.org` (Mullvad exit IP). The same treatment is applied to Bolt Launcher and Stremio via wrappers in `modules/base/home-base.nix`. Nixpkgs' `prismlauncher` wrapper already puts wayland-patched GLFW (`glfw3-minecraft`) and `gamemode.lib` into the game's `LD_LIBRARY_PATH` by default, and exposes all bundled JDKs via `PRISMLAUNCHER_JAVA_PATHS`; there is no `withWaylandGLFW` argument (common misconception).

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
