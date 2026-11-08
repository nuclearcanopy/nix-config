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

      # Kingston HyperX Virtual Surround Sound (0951:16a4) crashes the Steam
      # client. It registers an alsa card that carries no sink and no source,
      # and the 32-bit libpulse inside steam-runtime segfaults in libaudio.so
      # while dispatching that card's info reply (backtrace: libaudio.so <-
      # libpulse.so.0 <- pa_pdispatch_run), killing the whole client ~15s into
      # startup with no error, only a core dump in $HOME. Proven by
      # elimination: `PULSE_SERVER=/nonexistent steam` survives, and so does a
      # normal launch once this card is gone. The dongle is unused, so drop it
      # at the monitor instead of leaving a landmine for whenever it gets
      # plugged back in. Remove this block if the device is ever actually
      # needed. (The suspend-timeout rule that used to sit alongside this now
      # lives in audio-rt-base, shared with the laptop.)
      wireplumber.extraConfig = {
        "52-disable-hyperx-surround" = {
          "monitor.alsa.rules" = [{
            matches = [
              { "device.name" = "~alsa_card.usb-Kingston_HyperX_Virtual_Surround_Sound.*"; }
            ];
            actions = {
              update-props = {
                "device.disabled" = true;
              };
            };
          }];
        };
      };

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
