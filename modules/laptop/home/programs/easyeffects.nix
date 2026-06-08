{ ... }:

# Mic + speaker effects via easyeffects. Runs as a user systemd service so
# presets apply without the GUI being open. Launch `easyeffects` to open the
# GUI and build/tweak presets, then enable them on the Input pipeline.
{
  services.easyeffects.enable = true;
}
