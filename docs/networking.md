# networking (nidhoggr)

forensic detail for the mullvad relink/dispatcher rewrite. see the pointer comments in `modules/networking/network-laptop.nix` for where each section applies.

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
