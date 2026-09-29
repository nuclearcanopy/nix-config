{ config, ... }:

{
  # Low-latency PipeWire + JACK setup for desktop (kuraokami).
  # Laptop (audio-basic) shares the rtkit/RT-priority stack via audio-rt-base;
  # it's slimmer only in that it lacks JACK and the udev "keep usb audio
  # awake" power-control rule below.
  nixos.modules.audio-jack = {
    imports = [ config.nixos.modules.audio-rt-base ];

    # keep usb audio awake
    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="usb", ATTR{bInterfaceClass}=="01", TEST=="power/control", ATTR{power/control}="on"
    '';

    services.pipewire = {
      jack.enable = true;

      extraConfig.pipewire = {
        "92-low-latency" = {
          "context.properties" = {
            "default.clock.rate" = 48000;
            "default.clock.quantum" = 1024;
            "default.clock.min-quantum" = 512;
            "default.clock.max-quantum" = 2048;
            "default.clock.allowed-rates" = [ 44100 48000 ];
            "support.dbus" = true;
            "rt.prio" = 88;
            "nice.level" = -11;
          };
        };
      };

      extraConfig.pipewire-pulse = {
        "92-pulse-no-suspend" = {
          "pulse.properties" = {
            "pulse.min.quantum" = "1024/48000";
          };
          "stream.properties" = {
            "resample.quality" = 10;
            "channelmix.upmix" = true;
            "channelmix.lfe-cutoff" = 150;
          };
        };
      };
    };
  };
}
