{ ... }:

# Standard PipeWire setup — no low-latency RT tuning.
# Removed from kuraokami: JACK, rtkit high-prio limits, custom quantum/rate config,
# USB audio keepalive, wireplumber suspend-disable rules.
# These were all for a studio/gaming use case; a laptop just needs normal audio.
{
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;

    alsa = {
      enable = true;
      support32Bit = true;
    };

    pulse.enable = true;
    wireplumber.enable = true;
  };
}
