# gui theming (desktop + laptop)

forensic detail for the oled/qt palette work. see the pointer comment in `modules/gui/theme.nix` for where this applies.

**helium was removed 2026-10-24** (dropped the `helium` flake input to cut external/less-vetted flakes). the investigation below is kept for history since the qt6ct forcing mechanism it motivated is still in place for any future qt6 chromium-based app.

## helium/chromium can't have both pure-black chrome and a visible active tab

chromium's qt path (which helium runs on via `extensions.theme.system_theme = 2`) paints the frame, tab strip, inactive tabs, the *active* tab, and the toolbar all from `QPalette::Button`. with `Button = #000000` there is nothing left to visually mark the selected tab, so pure-black chrome and a visible active tab are mutually exclusive under the qt theme. verified 2026-08-25 by running a scratch profile against a deliberately garish debug palette with `Highlight`/`Window`/`Link` all set to distinct colors, to see which role painted what.

the same investigation found chromium's qt path also draws the new-tab "+" button from `QPalette::Highlight`, the same role used for page and omnibox text selection. an accent blue was tried on `Highlight` for selection contrast and reverted, because it also turned the "+" button blue; the two share one role and cannot be split. selection/accent stays a light grey (`#3a3a3a` on white) for this reason, and `Link` (role 14) stays grey too.

two escapes exist, both declined:

- the classic theme in `helium://settings/appearance` (frame `#1e2020`, active tab + toolbar `#3a3c3c`)
- a theme extension: a bare `manifest.json` with a `theme.colors` table, loaded via `--load-extension=<dir>` (helium accepts this without developer mode), whose `frame` and `toolbar` keys are independent. measured at black frame/inactive tabs with a `#1a1a1a` active tab. but installing any theme extension takes helium off the qt palette entirely, and its menus and omnibox dropdown revert to chromium's default dark grey.

black was chosen deliberately; the tab-boundary ambiguity is an accepted cost.

## light/dark theme toggle (`set-theme-mode`, `modules/gui/theme-mode.nix`)

Every themed surface (gtk, qt6ct/qt5ct, waybar, mako, bemenu, sway borders/
wallpaper, alacritty, firefox chrome) is declared twice by nix, dark and
light, at stable paths. `set-theme-mode {light|dark|toggle}` flips which
variant is live by re-pointing a plain symlink per app (never editing file
contents at runtime) and firing whatever reload each app needs (`makoctl
reload`, `swaymsg reload`, a waybar signal, nothing for apps that inotify-
watch their own config). This exists because home-manager owns these files as
immutable store-path symlinks regenerated only on `home-manager switch`, so a
fast runtime toggle needs the nix layer to stop picking a single value and
instead publish both, with a script choosing between them. `theme-mode-restore`
(a `sway-session.target` user service, same convention as every other HM user
service in this repo) re-applies the persisted choice from
`~/.local/state/theme-mode/current` on every login, since a rebuild resets
the symlinks back to the nix-level dark default.

Firefox is the one exception with no live reload: `userChrome.css` is
startup-only, so the toggle swaps the file and fires a mako notification
asking for a manual restart rather than killing the browser process.

Canonical dark->light hex mapping, reused mechanically everywhere so the two
variants of any given file are a 1:1 substitution, not independently
redesigned:

| role | dark | light |
|---|---|---|
| base background | `#000000` | `#f0f0f0` |
| raised surface (card/entry/tooltip) | `#0a0a0a` | `#ffffff` |
| hover | `#1c1c1c` | `#e2e2e2` |
| active/pressed | `#272727` | `#d4d4d4` |
| selected tab | `#171717` | `#e8e8e8` |
| primary text | `#949494` | `#2b2b2b` |
| secondary/dim text | `#757575` | `#868686` |
| disabled text | `#4d4d4d` | `#a8a8a8` |
| disabled text (dim) | `#333333` | `#cccccc` |
| accent bg (selection/switch) | `#3a3a3a` | `#c7c7c7` |
| accent fg (on accent bg) | `#ffffff` | `#000000` |
| accent secondary (link) | `#b0b0b0` | `#5a5a5a` |
| accent mid (visited link) | `#6e6e6e` | `#8a8a8a` |
| border, focused | `#121212` | `#a0a0a0` |
| border, unfocused | `#050505` | `#e2e2e2` |
| border, focused-inactive | `#0b0b0b` | `#cfcfcf` |

Status/alert colors (waybar's muted-mic/caffeine/dock red `#b96b6b`, airgap's
yellow `#C6A857`/red `#B96B6B`, thermal-mode's red/yellow) stay identical in
both modes; they're semantic signals, not theme surface colors. Alacritty's
ANSI red/green/yellow/blue/magenta are the same exception (git-diff colors
etc.) — only black/white/bg/fg/cursor/selection flip there.
