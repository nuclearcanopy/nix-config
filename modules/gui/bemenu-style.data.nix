# Shared bemenu appearance flags (OLED palette, matches modules/gui/theme.nix).
# A plain string, not a module: imported by sway-base.nix for the launcher and
# run-dialog, and by sway-host.nix for host-only pickers, so a retheme lands in
# one place instead of drifting between them.
''-i -c -l 5 -W 0.20 -B 0 -p "" --fn "monospace 16" --tb "#000000" --tf "#cccccc" --fb "#000000" --ff "#cccccc" --nb "#000000" --nf "#888888" --ab "#000000" --af "#888888" --hb "#000000" --hf "#ffffff" --sb "#000000" --sf "#ffffff" --scb "#000000" --scf "#888888"''
