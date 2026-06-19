{
  # Standard PipeWire setup for laptop: no JACK, no RT limits, no USB audio
  # keepalive, no wireplumber suspend-disable. Smaller quantum (64) for low
  # latency; can be raised if power becomes an issue.
  nixos.modules.audio-basic = {
    security.rtkit.enable = true;

    services.pipewire = {
      enable = true;

      alsa = {
        enable = true;
        support32Bit = true;
      };

      pulse.enable = true;

      extraConfig.pipewire."10-laptop-quantum" = {
        "context.properties" = {
          "default.clock.rate" = 48000;
          "default.clock.quantum" = 64;
          "default.clock.min-quantum" = 64;
          "default.clock.max-quantum" = 512;
        };
      };
    };
  };
}
