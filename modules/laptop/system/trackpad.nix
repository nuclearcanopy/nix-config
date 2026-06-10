{ ... }:

# Synaptics PS/2 touchpad tuning.
# rate=200 selects the chip's high-rate report mode (~100Hz sustained,
# ~130Hz peak during fast swipes) instead of the default ~80Hz.
# synaptics_intertouch=0 keeps psmouse on the PS/2 path and prevents an
# auto-switch to RMI4-over-SMBus, which on this particular chip
# (TM3471-020) regresses to ~63Hz.
# resetafter=0 disables psmouse's periodic chip reset, which otherwise
# introduces brief micro-stutters every few seconds.
{
  boot.extraModprobeConfig = ''
    options psmouse synaptics_intertouch=0 resetafter=0 rate=200
  '';
}
