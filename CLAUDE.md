# CLAUDE.md

Guidance for working on this NixOS configuration repository. This file is a high‑signal, low‑ambiguity map for AI agents; keep it current.

## Overview
This is a personal NixOS flake for the host `kuraokami` (desktop) and `nidhoggr` (ThinkPad T480 laptop) with home‑manager, agenix, NUR, and nixvim, plus a headless `homeserver` host in `hosts/homeserver`. It uses Sway (Wayland), low‑latency PipeWire + JACK, LACT for AMD GPU control (desktop), `scx_lavd` + ananicy for CPU scheduling, a `performance` CPU governor (desktop), Mullvad VPN (sole VPN provider), and a privacy‑tuned desktop. Both hosts run the CachyOS kernel (`pkgs.cachyosKernels.linuxPackages-cachyos-latest-x86_64-v3`); kuraokami in `modules/system/core/boot.nix`, nidhoggr in `modules/laptop/system/boot.nix`. Bolt Launcher is wrapped with Mullvad exclusion and exposed via a desktop entry on desktop/laptop profiles. Laptop power uses aggressive TLP battery profiles (2 GHz cap, boost off on BAT; full performance on AC), AC‑aware swayidle (dim/sleep on battery, 30min idle on AC), profile‑sync‑daemon for Firefox in RAM, 40ms keyboard debounce via interception‑tools, and a waybar Fn+Q power profile indicator. Laptop NetworkManager randomizes the MAC on every wifi and ethernet connection (`wifi.macAddress = "random"`, `ethernet.macAddress = "random"`) in addition to scan-time randomization. Mullvad on `nidhoggr` runs in **lockdown mode**: `modules/networking/network-laptop.nix` defines `mullvad-lockdown.service` (`wantedBy` `mullvad-daemon.service`) which sets `lockdown-mode on` + `auto-connect on` every boot, so the daemon holds a blocking firewall policy any time the tunnel is not up, including before it has ever connected and while the daemon is stopped. There is no traffic off the box except through Mullvad (LAN excepted). The NM dispatcher (`mullvad-relink-dispatcher`) no longer touches the tunnel itself; it ignores `lo`/`wg*`/`tun*` and fires `systemctl start --no-block mullvad-relink.service`, which polls `mullvad status` for up to 60s and re-issues `connect` whenever the state is neither Connected nor Connecting. That poll captures the full `status` output and cuts the first line in-shell rather than piping into `head -n1`: `mullvad status` prints four lines, `head` closes the pipe after the first, and the SIGPIPE that killed the daemon-side write became 141 through `pipefail` + the NixOS script wrapper's `set -e`, killing the unit on its first iteration (seen 2026-08-25). The race only lands while the daemon is mid-reconnect, i.e. exactly when the service matters. `mullvad-relink` also runs `wantedBy graphical.target` `after mullvad-autoconnect.service`, because the shared autoconnect script gates its `connect` on NM connectivity `full` and that verdict never arrives here. This replaced a dispatcher that read NM's *cached* `nmcli -t networking connectivity` and ran `mullvad disconnect` on `limited`: during a link flap that cache is stale, so it tore down tunnels the daemon was already recovering and, because `mullvad disconnect` resets the whole firewall policy, left the machine with no killswitch (observed 2026-08-22: 39s and 55s unprotected windows, visible in the daemon journal as `Resetting firewall policy` while a `Connecting to ...` was in flight). It also fired on `up` for `wg0-mullvad` itself, disconnecting the tunnel it had just built. Captive-portal handling was removed entirely: NM's connectivity check override is gone (the privacy module's blanket disable now stands) and `programs.captive-browser` was dropped, since its SOCKS5 proxy is blocked by the Mullvad firewall like everything else and it dragged chromium into the closure. Portals are now manual: `mullvad lockdown-mode set off`, log in, `systemctl restart mullvad-lockdown` to re-arm. Note `mullvad-vpn` (2026.3, in `modules/base/system-packages-laptop.nix`) shadows the daemon's own CLI from `services.mullvad-vpn.package` (`pkgs.mullvad`, 2026.2) in `PATH`, so shell `mullvad auto-connect get` / `lockdown-mode get` / `relay get` fail with `Failed to parse gRPC response: invalid LWO settings`; the systemd units call `${pkgs.mullvad}/bin/mullvad` directly and are unaffected. Waybar on both `kuraokami` and `nidhoggr` exposes a `custom/airgap` toggle (`NET`/`AIR`) that calls `nmcli networking off`, `nmcli radio all off`, `bluetoothctl power off`, and `rfkill block bluetooth` to cut all wired+wireless+bluetooth connectivity with a middle-click (`on-click-middle` only, so a stray left-click cannot trigger it); middle-clicking again restores wifi/ethernet radios and NM (bluetooth stays off until the user re-enables it via the BTH module). Because `nmcli networking off` persists `NetworkingEnabled=false` to `/var/lib/NetworkManager/NetworkManager.state`, airgap survives a reboot; clearing it requires `nmcli networking on` or another middle-click (a plain reboot will not restore connectivity). Unless networking is definitively enabled (`nmcli -t networking = enabled`), `bt_toggle.sh` refuses to power on and re-blocks the radio, so the BTH module cannot bring bluetooth back up until airgap is exited. That test is fail-closed by design: it previously checked `= "disabled"`, which let an unreachable NetworkManager (empty nmcli output) fall through to the power-on path. The two scripts live in `modules/gui/waybar/scripts/airgap_{mode,toggle}.sh` and are referenced by both hosts' waybar configs. All three scripts wrap their `nmcli` calls in `timeout`, and `airgap_mode.sh` matches the state exhaustively: `enabled` → `NET`, `disabled` → red `AIR`, anything else (NM wedged, not answering D-Bus) → red `ERR`. The `ERR` state exists because a NetworkManager stuck in the kernel holding RTNL renders as empty nmcli output, and the old `!= enabled` test drew that as `AIR`, making it look like airgap had armed itself when connectivity was never disabled; a middle-click in that state now bails without arming the flag file instead of issuing an `nmcli networking on` that cannot land. `set-cpu-mode {spd|bal|lap|god|auto}` is sticky: the chosen mode is persisted to `/var/lib/cpu-mode/state` and `cpu-mode-restore.service` re-applies it after every event TLP also reacts to (boot, AC/BAT change, resume), so god mode survives plug/unplug. `auto` clears the state and lets TLP drive again. God mode also caps CPU idle at C3 (disables `cpuidle/state4` C6 and `state5` C7s via sysfs, wheel-writable via the same udev rule as cpufreq) to trade a bit of idle power for ~30µs wake latency vs C7s's ~100µs; other modes re-enable both states. Laptop (ThinkPad T480) bootloader: GRUB with `device = "nodev"` and `efiSupport = true`; Libreboot (Deguard) firmware GRUB reads `/boot/grub/grub.cfg` generated by NixOS GRUB. EFI fallback kept as contingency until Libreboot is confirmed stable. ESP is FAT32 512M (`p1`, `/boot`), LUKS root is `p2`. Shared modules in `modules/shared/` deduplicate sway config, host base (user/locale/sudo), home base (xdg/trash), kernel hardening params+sysctl (`hardening.nix`: pti/PTI, init_on_alloc+init_on_free, randomize_kstack_offset, slab_nomerge, kptr_restrict, dmesg_restrict, perf_event_paranoid=3, unprivileged_bpf_disabled, bpf_jit_harden=2, yama.ptrace_scope=2, kexec_load_disabled, sysrq=4, unprivileged_userfaultfd=0), common system packages (`packages.nix`), and Mullvad autoconnect service (`mullvad-autoconnect.nix`) across hosts. Laptop adds further hardening in `modules/laptop/system/hardening.nix`: VT-d IOMMU forced strict (`intel_iommu=on iommu=force iommu.strict=1 iommu.passthrough=0`), `thunderbolt` and `firewire-*` kernel modules blacklisted to kill PCIe-tunnel DMA (USB-C PD charging and plain-USB devices like YubiKey still work via the EC and xHCI mux; TB PCIe devices 0000:04:00.0 NHI + 0000:06:00.0 USB controller are pinned `power/control=on` via udev because without a driver they can't return from D3cold, causing `libvirtd PCI header type 127` and `xhci_hcd HC died` errors), AppArmor with killUnconfinedConfinables, and USBGuard block-by-default for newly inserted devices (presentDevicePolicy=allow so internal webcam/fingerprint reader survive a reboot). USBGuard is fully declarative via `services.usbguard.rules` in `modules/security/hardening-physical.nix` (Yubico `1050:*`, the Logitech receiver, the HHKB, the Razer DeathAdder V4 Pro, the iPhone, the AX210 BT radio, and two USB-C audio dongles). Two things make a blocked insert usable without a terminal: `usbguard-notifier` runs as a systemd user service and raises a mako notification whenever a device is blocked, and **Mod+Shift+U** (`modules/gui/waybar/scripts/usb_allow.sh`, bound in the nidhoggr block of `sway-host.nix`) lists blocked devices by name in bemenu and authorizes the pick. Both work unprivileged because the user is in `IPCAllowedUsers`. That authorization lasts **until reboot only**: the ruleset is nix-store immutable, so the legacy `allow-device -p` persistence does not work. To trust a device permanently, add `allow id <vid>:<pid>` to that module and rebuild; the notification prints the id for copying. Bluetooth is enabled (`modules/hardware/bluetooth.nix`) with `powerOnBoot = false` and toggled via the waybar `custom/bluetooth` button (green `BTH` #71A671 when live, white `BTH` when off); off = `bluetoothctl power off` + `rfkill block bluetooth` (kernel radio cut, no scanning/advertising possible), on = `rfkill unblock bluetooth` + `bluetoothctl power on`. USBGuard has `allow id 8087:0032` for the internal AX210 BT radio; `services.blueman.enable = true` gives a tray for pairing. The waybar airgap toggle still calls `bluetoothctl power off` harmlessly. JOP hardware mitigations (Intel CET shadow stack + IBT) are unavailable on the i5-8350U (Coffee Lake / 8th gen, pre-Tiger Lake), so JOP defense is software-only. Retbleed mitigation is explicitly disabled via `retbleed=off` in `modules/boot/boot-t480.nix` kernelParams: software IBRS costs ~10-25% on branch-heavy code (JS engines) and the perf tradeoff is deliberate; PTI (Meltdown), Spectre v1, MDS, TSX-AA, MMIO stale data, and SRBDS mitigations all remain on. Suspend is S3 (`mem_sleep_default=deep`, switched from `s2idle` 2026-08-22 for the ~8-10%/h lid-shut drain win) and `pcie_port_pm=off` was dropped in the same change. On the first long S3 cycle under those params the AX210 (`0000:01:00.0`, behind root port `0000:00:1c.0`) failed to resume: MMIO reads returned all-`0xff` and AER logged `Uncorrectable (Fatal), type=Inaccessible` then `can't recover (no error_detected callback)`. iwlwifi registers no `error_detected` AER callback, so the kernel cannot reset the card; NetworkManager was mid-`ifup` (`do_setlink` → `ieee80211_open` → `drv_start` → `iwl_poll_bits_mask`) and spun there holding **RTNL** plus the iwlmvm mutex. A task spinning in kernel context cannot be signalled, so `systemctl stop NetworkManager` never completed (`TimeoutStopSec` is irrelevant), `tlp-sleep`'s `iw` blocked on RTNL too, and shutdown wedged into a force power-off. Mitigations, both in place: `iwlwifi` is on TLP's `RUNTIME_PM_DRIVER_DENYLIST` in `modules/power/tlp.nix` (same precedent as `thunderbolt xhci_hcd`, whose comment documents the identical D3cold-then-fail-to-resume class), and `iwlwifi.remove_when_gone=1` in kernelParams makes the driver tear down and rescan a device that has fallen off the bus rather than spin on it. If the wedge recurs, the proven-good fallback is re-adding `pcie_port_pm=off` (boots with it logged zero AER events; the first boot without it logged 12). Battery charge thresholds are managed by TLP via `START_CHARGE_THRESH_BAT1`/`STOP_CHARGE_THRESH_BAT1` in `modules/power/tlp.nix`. Currently 20/80 for longevity; ThinkPad EC only initiates charging when below START, so a plug-in above 20% keeps the pack idle until it drops below 20%, then tops up to 80%. Both batteries are present via Power Bridge: BAT0 internal LGC 01AV420 (~24Wh Li-poly) and BAT1 removable LGC 01AV427 (~80Wh Li-ion); both accept threshold writes via `thinkpad_acpi` (kernel log at boot: `battery 1 registered (start ..., stop ..., behaviours: 0x1)` for both). TLP currently only writes thresholds for BAT1; BAT0 rides the EC defaults. Waybar `custom/battery` script combines both via voltage-weighted Wh to display a single % and time estimate. This requires the Libreboot coreboot fix: `CONFIG_MAINBOARD_SMBIOS_PRODUCT_NAME="ThinkPad T480"` in both config files under `~/libreboot/lbmk/config/coreboot/t480_vfsp_16mb/config/`. TLP 1.8+ has explicit Libreboot support: it checks `product_name` when `product_version` lacks "ThinkPad", so once the ROM is reflashed, TLP uses its thinkpad plugin with natacpi on BAT1. XHC wakeup suppression and CPU sysfs permissions are still set via `services.udev.extraRules` in `modules/laptop/system/power.nix`. Desktop theming lives in `modules/gui/theme.nix`: a pitch-black OLED palette (`#000000` surfaces, `#949494` text) injected as `gtk3/gtk4.extraCss` on top of `Adwaita-dark`, mirrored into a Qt Fusion custom palette at `qt6ct/colors/oled.conf` (21 QPalette roles × active/disabled/inactive) because Qt apps and Helium ignore the GTK CSS; `QT_QPA_PLATFORMTHEME` is forced to `qt6ct` (Qt5-only apps therefore fall back to default Fusion). Selection/accent is a light grey `#3a3a3a` on white in both halves (`accent_bg_color`/`theme_selected_bg_color` in the CSS, roles 12/13 Highlight/HighlightedText in the Qt palette), which is also what colors text selection in Helium. It is deliberately greyscale: Chromium's Qt path draws the new-tab "+" button from `QPalette::Highlight` too, so an accent blue there (tried 2026-08-25) turns the "+" button blue as well; the two share one role and cannot be split. Helium runs on the Qt theme (`extensions.theme.system_theme = 2` in its per-profile Preferences, not declarative) and Chromium's Qt path paints the frame, tab strip, inactive tabs, the *active* tab and the toolbar all from `QPalette::Button`, with only the new-tab "+" button from `QPalette::Window` (verified 2026-08-25 with a scratch profile against a deliberately garish debug palette). With `Button = #000000` there is nothing left to mark the selected tab, so pure-black chrome and a visible active tab cannot coexist. Two escapes exist, both declined: the Classic theme in `helium://settings/appearance` (frame `#1e2020`, active tab + toolbar `#3a3c3c`), or a theme extension (a bare `manifest.json` with a `theme.colors` table, loaded with `--load-extension=<dir>`, which Helium accepts without developer mode) whose `frame` and `toolbar` keys are independent; that was measured at black frame/inactive tabs with a `#1a1a1a` active tab, but installing any theme takes Helium off the Qt palette and its menus and omnibox dropdown revert to Chromium's dark grey. Black was chosen deliberately. The `allowedUnfree` list is defined once in `flake.nix` and passed via `specialArgs` to all hosts. Homeserver `username = "homeserver"` is in `specialArgs` and used throughout server modules. Primary entrypoints: `flake.nix` and `hosts/<host>/configuration.nix`.

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
- Encrypted secrets: `secrets/*.age` (e.g., `ssh-git.age`, `ssh-github.age`, `nas-credentials.age`, `user-password.age`).
- Identity path: `/etc/age/key.txt` (provided by the user; wired in `modules/system/secrets.nix`).

The system uses agenix; do not commit plaintext secrets.

Two SSH keys, split by purpose: `ssh-git.age` → `/run/agenix/ssh-git` is the homeserver login key (laptop/desktop → homeserver; the matching pubkey is in `modules/server/users.nix` `authorizedKeys` and is materialized locally at `~/.ssh/id_ed25519_homeserver.pub`), and `ssh-github.age` → `/run/agenix/ssh-github` is the git forge key for `github.com` (pubkey at `~/.ssh/id_ed25519_github.pub`). Both are declared in `modules/base/secrets.nix` and routed in `modules/shell/ssh.nix`; the homeserver gets `ssh-github` symlinked to `~/.ssh/id_github` by `modules/server/git.nix` so it can pull the flake. `agenix` is not installed as a CLI; to add or rotate a secret, add the filename to `secrets/secrets.nix` and encrypt directly with `age -r <recipient-from-secrets.nix> -o secrets/<name>.age <plaintext>` (all three hosts share the one age recipient, so a single `-r` matches what agenix would emit). New `.age` files must be `git add`-ed before the flake can see them.

GitHub is the only forge. The repo lives at `github.com/nuclearcanopy/nix-config`, the remote is named `github`, and there is no second remote; `nix-commit`/`nix-clone` push and pull `github main`.

## Private identity flake (eval-time values)
Agenix decrypts at **activation** time, which is far too late for anything the Nix **evaluator** needs: `username` feeds `users.users.<name>`, home-manager paths, and agenix's own `owner =`. A username therefore cannot be an agenix secret; there is no version of that which works. Values in that class live in a separate private flake, `git+ssh://git@github.com/nuclearcanopy/identity.git`, wired as the `identity` input in `flake.nix` and read as `inputs.identity.usernames.<host>`. Currently it holds only `usernames.kuraokami`, since `nidhoggr` (`loki`) and `homeserver` are already public. Consequences: **read access to that repo is required to evaluate this flake at all** (a missing key surfaces as a git fetch error, not a Nix error), `flake.lock` pins its rev and URL but never its contents, and the fetched source does land world-readable in `/nix/store` on the machine itself, so this hides the value from the public repo, not from a local user. To rotate or add a value, commit to the identity repo and run `nix flake lock --update-input identity`.

Homeserver secrets are wired in `modules/server/secrets.nix` and include `homeserver-user-password.age`, `homeserver-navidrome-env.age`, `homeserver-searxng-env.age`, `homeserver-cloudflared-credentials.age`, and `homeserver-mscd-api-hash.age`.

## Homeserver streaming reliability (`modules/server/services.nix`)
Navidrome is configured for resilient Subsonic streaming: 5GB transcoding cache, 500MB image cache, opus default downsampling, 6h scan schedule, 168h sessions, downloads enabled, scan log lines remain at `info` level (the boost sidecar trigger needs them). The container's `environmentFiles` list reads `homeserver-navidrome-env.age` AND a local mode-600 file at `/var/lib/navidrome/lastfm.env` (the latter wins per docker env-file "last duplicate key wins" — it lets us rotate the Last.fm API key on-host without re-encrypting the agenix secret, which is only decryptable from `kuraokami`). `docker-navidrome.service` has `Restart=always` with 5s backoff.

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
    system/             → TLP, boot tuning, keyboard debounce, power, network, hardening (IOMMU/USBGuard/TB blacklist/AppArmor), trackpad (Synaptics PS/2 rate=200 ~100Hz via SMBus-enabled coreboot)
  laptop/home/          → laptop home-manager config
    desktop/            → sway, swayidle (AC-aware), waybar (battery + power profile)
secrets/                → Encrypted secrets (*.age) and key mappings
scripts/install.sh      → disko-based install flow (fresh installs)
```

## Conventions
- Nix files use 2‑space indentation.
- Username is set per host in `modules/computers/<host>.nix` (`nixos.configurations.<host>.username`) and passed via `specialArgs`. `nidhoggr` and `homeserver` hardcode theirs; `kuraokami` reads `inputs.identity.usernames.kuraokami` from the private identity flake (see below). No `/etc/identity.nix`, no `--impure` flag.
- Unstable packages are accessed as `pkgs.unstable.<name>` where needed.
- Avoid hardcoding usernames in module bodies.
- Prefer placing new configuration in the appropriate module rather than `hosts/<host>/system.nix`.

## Adding Packages
- System: `modules/system/core/packages.nix`
- Desktop apps: `modules/home/desktop/packages.nix`
- User programs: `modules/home/programs/packages.nix`
- Dev tools: `modules/home/dev/packages.nix`
- Unfree allowlist: `modules/system/core/packages.nix`

## Laptop software minimalism (nidhoggr, 2026-09-06)

`nidhoggr` is deliberately kept lean; the system closure was 41.8 GiB before this pass. When adding anything here, price it first (`nix path-info -S`) and prefer the smaller option. What was removed and why:

| Removed | Was | Why |
|---|---|---|
| `texliveFull` | 6.3 GB | full TeX distribution. `lyx` is still installed but **has no TeX backend and will not typeset**; either add a `texliveSmall`-class scheme or drop lyx |
| `kdenlive` / `teams-for-linux` / `rustdesk-flutter` / `feishin` / `mangohud` | ~10 GB | unused, or duplicated by something lighter. `termsonic` is now the only Subsonic client |
| `thunar` + `tumbler` + `xfconf` + `thunar-volman` | ~2.4 GB | replaced by `pcmanfm` (~310 MB), `modules/programs/pcmanfm.nix`. `gvfs` stays: GTK file managers mount removable media through it, and dropping it costs USB automount and the GUI trash backend |
| `openrazer` + `polychromatic` | | moved to kuraokami only. A DeathAdder V4 Pro still gets used on nidhoggr (see the USBGuard rules and the input block in `sway-host.nix`); without openrazer it works as plain HID but loses battery reporting and DPI/RGB control |
| `fwupd` | | Libreboot has no UEFI capsule path, so the only updatable device it could see was the NVMe. It cost a resident daemon plus an `fwupd-refresh` LVFS request on a lockdown-mode Mullvad host. Ad hoc: `nix shell nixpkgs#fwupd -c fwupdmgr get-updates`. Its boot-time timer/service tuning was removed from `boot-optimizations.nix` in the same change, because a `timerConfig` for a non-existent unit still emits a broken timer |
| `systemd-oomd` | | `systemd.oomd.enable = false` lives in `modules/base/earlyoom.nix`. Both OOM killers were running with different trigger models (oomd kills cgroups on PSI pressure, earlyoom kills the fattest process on a free-memory threshold), making the outcome unpredictable |
| `speech-dispatcher` | 1.24 GB | `services.speechd.enable = false` in the host file. nixpkgs default-enables it; nothing here asks for it. Output-only, so the mic path is unaffected; the loss is Firefox "Read Aloud" and screen readers |

Deliberately kept after review: `easyeffects` (125 MB resident, the largest user service), `xembedsniproxy` (2.85 GB of plasma-workspace for the Java AWT tray shim), `obs-studio`, Steam, the security toolkit, and `gvfs`.

pcmanfm automount is **off by default** and is not managed declaratively; enable it under Edit > Preferences > Volume Management. The setting lands in `~/.config/pcmanfm/default/pcmanfm.conf`.

Known-broken, untouched: `sleep-actions.service` (the unit that runs `powerManagement.resumeCommands` from `modules/power/power-suspend.nix`) fails on **every resume**. `pkill` is not in the unit's PATH, and `set -e` aborts the script when `v=$(cat "$devdir/idVendor")` hits a USB interface directory that has no `idVendor`. Net effect: the backlight redraw and the waybar resume signal never run.

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


## AI Maintenance Reminder (Mandatory)
- If you change behavior, modules, packages, or workflow, update `CLAUDE.md`, `AGENTS.md`, and `README.md` in the same PR.
- Keep summaries precise and concrete (paths, commands, ports, services, modules).
- When you see drift, update these docs before or alongside the code change.
