# gui theming (desktop + laptop)

forensic detail for the oled/qt palette work. see the pointer comment in `modules/gui/theme.nix` for where this applies.

## helium/chromium can't have both pure-black chrome and a visible active tab

chromium's qt path (which helium runs on via `extensions.theme.system_theme = 2`) paints the frame, tab strip, inactive tabs, the *active* tab, and the toolbar all from `QPalette::Button`. with `Button = #000000` there is nothing left to visually mark the selected tab, so pure-black chrome and a visible active tab are mutually exclusive under the qt theme. verified 2026-08-25 by running a scratch profile against a deliberately garish debug palette with `Highlight`/`Window`/`Link` all set to distinct colors, to see which role painted what.

the same investigation found chromium's qt path also draws the new-tab "+" button from `QPalette::Highlight`, the same role used for page and omnibox text selection. an accent blue was tried on `Highlight` for selection contrast and reverted, because it also turned the "+" button blue; the two share one role and cannot be split. selection/accent stays a light grey (`#3a3a3a` on white) for this reason, and `Link` (role 14) stays grey too.

two escapes exist, both declined:

- the classic theme in `helium://settings/appearance` (frame `#1e2020`, active tab + toolbar `#3a3c3c`)
- a theme extension: a bare `manifest.json` with a `theme.colors` table, loaded via `--load-extension=<dir>` (helium accepts this without developer mode), whose `frame` and `toolbar` keys are independent. measured at black frame/inactive tabs with a `#1a1a1a` active tab. but installing any theme extension takes helium off the qt palette entirely, and its menus and omnibox dropdown revert to chromium's default dark grey.

black was chosen deliberately; the tab-boundary ambiguity is an accepted cost.
