{ config, ... }:

{
  # PipeWire setup for laptop (nidhoggr). No JACK, but full RT priority (via
  # audio-rt-base) so audio survives CPU throttling, TLP power events, and
  # heavy load. Quantum bumped from 64 (~1.3ms, xrun-prone on battery) to
  # 1024 (~21ms), with a 256 floor so apps can still request lower latency.
  nixos.modules.audio-basic = {
    imports = [ config.nixos.modules.audio-rt-base ];

    services.pipewire = {
      extraConfig.pipewire."10-laptop-quantum" = {
        "context.properties" = {
          "default.clock.rate" = 48000;
          "default.clock.quantum" = 1024;
          "default.clock.min-quantum" = 256;
          "default.clock.max-quantum" = 2048;
          # Lock to 48000 only. Allowing 44100 lets the graph switch rates
          # dynamically, and WebRTC streams (Teams, Firefox VC) that opened
          # at one rate keep producing at that rate while the graph runs at
          # the other, so audio gets resampled wrong and comes out with a
          # pitch shift (Teams "low pitch" bug that a pipewire restart fixed).
          # Locking makes every stream resample once against a fixed rate.
          "default.clock.allowed-rates" = [ 48000 ];
          "support.dbus" = true;
          "rt.prio" = 88;
          "nice.level" = -11;
        };
        # No mod.rt override: earlier config disabled the default mod.rt
        # and re-loaded it forcing rtkit-only, as a workaround for what was
        # actually the LimitNICE=19 bug (blocking direct nice writes).
        # With LimitNICE=40 the default mod.rt takes rt.prio direct via
        # LimitRTPRIO (95) and reaches SCHED_FIFO 88 without rtkit.
        # rtkit caps at prio 20, which is why the override left the
        # daemon's data-loop at SCHED_OTHER while wireplumber, pipewire-pulse,
        # and easyeffects (all default mod.rt) hit FIFO 83 cleanly.
      };

      # Firefox routes video-call audio through cubeb → pipewire-pulse, which
      # has its own quantum independent of the native pipewire graph. Without
      # a floor here it defaults to 128/48000 (~2.6ms), tiny buffer + shared
      # laptop CPU = dropouts. Pin to 1024 (~21ms) to match the native graph.
      extraConfig.pipewire-pulse."10-pulse-quantum" = {
        "pulse.properties" = {
          "pulse.min.quantum" = "1024/48000";
          "pulse.default.quantum" = "1024/48000";
        };
        "stream.properties" = {
          "resample.quality" = 10;
        };
      };
    };
  };
}
