{ ... }:

# Synaptics PS/2 touchpad tuning.
# rate=200 selects the chip's high-rate report mode.
# synaptics_intertouch=0 keeps psmouse on the PS/2 path and prevents an
# auto-switch to RMI4-over-SMBus, which on this particular chip
# (TM3471-020) regresses to ~63Hz.
# resetafter=0 disables psmouse's periodic chip reset, which otherwise
# introduces brief micro-stutters every few seconds.
# Steady-state polling is ~100Hz only when paired with the SMBus-enabled
# coreboot build (libreboot-nidhoggr patch). Without coreboot exposing
# pci 00:1f.4 the chip stays in a base mode and polls at ~70Hz even with
# rate=200 set — i2c-i801 init at coreboot time appears to put the chip
# in a higher-perf internal sampling mode that persists for the session
# even though Linux drives it via PS/2.
{
  boot.extraModprobeConfig = ''
    options psmouse synaptics_intertouch=1 resetafter=0 rate=200
  '';
}
