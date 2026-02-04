{ pkgs, ... }:

{
  # realtime
  security.rtkit.enable = true;

  # usb power
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{bInterfaceClass}=="01", TEST=="power/control", ATTR{power/control}="on"
  '';

  # pipewire
  services.pipewire = {
    enable = true;

    alsa = {
      enable = true;
      support32Bit = true;
    };

    jack.enable = true;

    wireplumber.extraConfig = {
      # no suspend
      "51-disable-suspension" = {
        "monitor.alsa.rules" = [{
          matches = [
            { "node.name" = "~alsa_output.*"; }
            { "node.name" = "~alsa_input.*"; }
          ];
          actions = {
            update-props = {
              "session.suspend-timeout-seconds" = 0;
            };
          };
        }];
      };
    };

    extraConfig.pipewire = {
      # low latency
      "92-low-latency" = {
        "context.properties" = {
          "default.clock.rate" = 48000;
          "default.clock.quantum" = 2048;
          "default.clock.min-quantum" = 1024;
          "default.clock.max-quantum" = 8192;
          "default.clock.allowed-rates" = [ 44100 48000 ];
        };
      };
    };

    extraConfig.pipewire-pulse = {
      # pulse
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
}
