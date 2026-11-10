# Networking VPN architecture

Nidhoggr uses Proton VPN's official GUI; the Mullvad relink/dispatcher notes below record the previous laptop implementation and remain useful for kuraokami and the homeserver.

## Proton VPN on Nidhoggr

`modules/networking/protonvpn-laptop.nix` installs the official `proton-vpn` GUI and starts `protonvpn-app` with the Sway session. The pinned 4.15.3 GUI supports FIDO2 security-key sign-in. Sign in from the app, then configure Advanced kill switch and auto-connect in its settings; those preferences and credentials remain in the user's home directory, never in Nix. Waybar reads the exit-country code from Proton's active NetworkManager profile name (for example, `ProtonVPN RO#185`), falling back to tunnel detection if no named profile is available; clicking the item opens the GUI. The Proton tray icon is available in Waybar's existing expand/tray group and provides the app's supported connect/disconnect menu. `vpnissue` and `netdebug` inspect NetworkManager and `wg show proton0`; they do not invoke the CLI, which must not run alongside the GUI.

Advanced kill switch preserves the former always-on lockdown behavior: normal internet remains blocked until Proton connects, and a deliberate disconnect does not unblock traffic. Disable Advanced kill switch in Proton's GUI when intentionally needing ordinary networking (for example, a captive portal). Split tunneling is not enabled on this NixOS setup, so laptop game/stream launchers use the Proton route; Mullvad exclusion wrappers remain only on kuraokami.

The GUI's auto-connect preference runs when its session app starts. The user service launches the app at each Sway session; select “start minimized to tray” if you prefer not to open its full window at login. The official app's tray menu can connect to fastest/pinned servers and disconnect. Do not launch the separate Proton CLI while the GUI is running.

## Historical Mullvad laptop behavior

The following sections describe the former Nidhoggr Mullvad implementation. Its autoconnect, relink dispatcher, and permanent lockdown services have been removed from that host.

## why the dispatcher no longer touches the tunnel directly

the previous dispatcher read networkmanager's *cached* `nmcli -t networking connectivity` and ran `mullvad disconnect` on `limited`. during a link flap that cache is stale, so it tore down tunnels the daemon was already recovering, and because `mullvad disconnect` resets the whole firewall policy, it left the machine with no killswitch. observed 2026-08-22: 39s and 55s unprotected windows, visible in the daemon journal as `resetting firewall policy` while a `connecting to ...` was in flight. it also fired on `up` for `wg0-mullvad` itself, disconnecting the tunnel it had just built.

the fix: the dispatcher (`mullvad-relink-dispatcher`) no longer acts inline. it ignores `lo`/`wg*`/`tun*` and just fires `systemctl start --no-block mullvad-relink.service`, which does the actual work and never issues `disconnect`, only `connect` (idempotent, safe to re-issue while the daemon retries).

## the head -n1 sigpipe bug

`mullvad-relink.service`'s poll loop originally piped `mullvad status` into `head -n1` to grab just the connection state line. `mullvad status` prints four lines (state, relay, features, location); `head -n1` closes the pipe after the first line, the daemon gets sigpipe writing the rest, `pipefail` turns that into exit 141, and the nixos script wrapper's `set -e` turned that into a dead unit on its very first iteration (seen 2026-08-25).

the race only lands while the daemon is mid-reconnect, i.e. exactly when the service matters most. fixed by capturing the full output into a variable and cutting the first line in-shell (`"''${out%%$'\n'*}"`) instead of piping into `head`.

## connectivity gating removed entirely

`mullvad-relink` used to gate its `connect` call on networkmanager reporting connectivity `full`. under lockdown mode that verdict never arrives: the connectivity probe can't reach anything until the tunnel is already up, so the gate deadlocked and the service burned its whole timeout loop before falling through. now there's no gating at all; `connect` is idempotent, so re-issuing it while the daemon retries is harmless.

this is also why `mullvad-relink` runs `wantedby graphical.target` `after mullvad-autoconnect.service` rather than depending on the autoconnect script's own connectivity check — that check would deadlock the same way at login.

## lockdown mode is the actual killswitch

`mullvad-lockdown.service` sets `lockdown-mode on` + `auto-connect on` on every boot (`wantedby mullvad-daemon.service`), so the daemon holds a blocking firewall policy any time the tunnel is not up, including before it has ever connected and while the daemon is stopped. there is no traffic off the box except through mullvad (lan excepted). deliberate consequence: captive portals are unreachable. to use one: `mullvad lockdown-mode set off`, log in, `systemctl restart mullvad-lockdown` to re-arm. nothing does that automatically.

captive-portal handling (`captive-browser`, the nm connectivity-check override) was removed entirely rather than worked around: its socks5 proxy was blocked by the mullvad firewall like everything else, so it never actually worked, and it dragged chromium into the closure for nothing.
