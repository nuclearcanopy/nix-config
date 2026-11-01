# terminal (kitty)

Kitty is the primary terminal because it implements the Kitty graphics protocol
used by the local mpv build's `--vo=kitty` output. That protocol lets mpv draw
video into a sub-rectangle of the terminal with explicit placement and layering.
Foot remains the more minimal option, but its Sixel path would require changing
that integration.

`modules/shell/kitty.nix` keeps Kitty's incidental UI hidden: no title
decorations, tab bar, command-finish notifications, update checks, or audio and
visual bells. The Kitty protocol itself remains enabled for inline graphics.

The dark/light palettes are declared as separate files. `set-theme-mode` swaps
`kitty/current-colors.conf`; restart Kitty after changing themes if the running
instance does not reload its included file.
