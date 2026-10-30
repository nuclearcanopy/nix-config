# terminal (ghostty)

why ghostty, what the non-obvious settings in `modules/shell/ghostty.nix` are for, and the startup numbers behind them. see the pointer comment at the top of that module.

## why ghostty and not foot

ghostty implements the **kitty graphics protocol**. the local mpv build (`0.41.0`) has a `kitty` video output with `--vo-kitty-cols/rows/left/top`, `--vo-kitty-alt-screen`, `--vo-kitty-config-clear` and `--vo-kitty-use-shm`, so a terminal media player can draw real video into a sub-rect of the grid. foot has sixel but not the kitty protocol, and sixel has no equivalent of kitty's placement/z-index or its shared-memory transmission path.

consequences for the config: nothing may disable or shrink inline graphics.

- `image-storage-limit` is raised from the 320MB default to 1GiB. it is a cap, not an allocation, and ghostty counts it **per screen**, so primary + alternate doubles the effective ceiling. video into a sub-rect transmits and frees a frame continuously; the headroom is there so ghostty does not evict a live placement mid-stream. setting this to `0` disables all image protocols, which is the one value that must never be used here.
- no `vt-*` clamp, no custom shader, and `window-vsync` is left at its default `true` (tear-free is wanted for video; it does not throttle pty reads).

## light/dark

ghostty is the only themed app here that needs neither a symlink nor a reload. `theme = dark:mono-dark,light:mono-light` makes it pick between the two theme files from the gtk portal's `org.freedesktop.appearance` `color-scheme`, which it subscribes to, so the switch is live.

that works because `set-theme-mode` writes `/org/gnome/desktop/interface/color-scheme` and `xdg-desktop-portal-gtk` (installed, serving `org.freedesktop.impl.portal.Settings`) republishes it. **that write used to be a no-op**: the script called `gsettings`, and glib is not installed anywhere in this config, so all three `gsettings set` lines failed silently under `2>/dev/null || true` and the runtime color-scheme never actually moved. it uses `${pkgs.dconf}/bin/dconf` now. verified by hand: `dconf write ... 'prefer-light'` flips the portal's `Read` result from `1` to `2` immediately.

the palettes are a 1:1 port of alacritty's `colors-{dark,light}.toml`, so the two terminals look identical during the changeover. note the terminal keeps the warmer `#f5f5f0` light background rather than the `#f0f0f0` the gtk/qt/waybar surfaces use; that predates ghostty and was carried over deliberately.

ghostty has no signal-free reload beyond this, for reference: there is no `SIGUSR2` handler in the binary's own right, but the shipped systemd unit is `Type=notify-reload` with `ReloadSignal=SIGUSR2`, so `systemctl --user reload app-com.mitchellh.ghostty.service` is the manual path if the portal route ever breaks. `ctrl+shift+,` is the in-window equivalent.

## startup, measured

the complaint was waiting to type. measured on nidhoggr under a normal working load, so treat the absolute numbers as an upper bound and the gaps as the real signal.

**shell init**, `zsh -i -c exit`, interleaved a/b, 15 reps each:

| | |
|---|---|
| before | 140ms |
| after | 100ms |

`zmodload zsh/zprof` put `compinit` at 57.8ms of which `compaudit` was 47.8ms, 74% of everything the rc did. the rc already had the standard "full `compinit` once a day, `compinit -C` otherwise" guard, but **it never once took the fast branch**: `compinit` only rewrites the dump when it judges it stale, so a dump that stays valid keeps its old mtime, `~/.zcompdump` sat at its september date, `(#qN.mh+24)` was therefore always true, and the expensive fpath security scan ran on every single interactive shell. `touch`ing the dump after the full run resets the window. the remaining 100ms is ~25ms `compinit -C`, ~25ms sourcing zsh-syntax-highlighting, ~20ms zsh-autosuggestions, ~15ms `scripts/nix-commit.zsh` and ~15ms zsh itself; those are all features worth their cost, measured individually by ablation.

**window spawn**, launch to the window appearing in sway's tree, interleaved against alacritty:

| | |
|---|---|
| alacritty | 135ms |
| ghostty, cold (no instance running) | 350ms |
| ghostty, warm instance, plain `ghostty` | 200ms |
| ghostty, warm instance, `ghostty +new-window` | 100ms |

ghostty is a gtk4/libadwaita/opengl app and is genuinely slower than alacritty to start from nothing; 350ms is the honest cold cost and no setting removes it. what removes it is never paying it after login:

- `gtk-single-instance = true` plus `quit-after-last-window-closed = false` keep one process resident, so it is always the warm row.
- the home-manager module's `systemd.enable` (on by default) installs ghostty's own unit, `WantedBy=graphical-session.target`, started `--initial-window=false`, plus the d-bus activation service. so the resident instance exists from login onward without opening a window.
- `ghostty +new-window` is a thin d-bus client that asks the resident instance for a window instead of starting a second gtk app and handing off. at 100ms it is the only path that beats alacritty, which is why `mod+q` is `ghostty +new-window || ghostty` rather than plain `ghostty`; the `||` is the fallback for a cold or unreachable instance, which otherwise exits 1 and opens nothing.

end to end, keypress to a usable prompt: ~275ms before (alacritty 135 + zsh 140), ~200ms after (ghostty 100 + zsh 100).

the cost of residency is one idle ghostty process holding a gl context for the whole session. if that shows up in battery or memory on this machine, `quit-after-last-window-closed = true` is the knob to flip back, at the price of a 350ms first window after every time the last one closes.
