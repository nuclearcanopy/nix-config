{ pkgs, ... }:

{
  # realtime audio
  security.rtkit.enable = true;

  # usb audio power
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
      # disable suspend globally
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
      # optimized low-latency settings
      "92-low-latency" = {
        "context.properties" = {
          "default.clock.rate" = 48000;
          "default.clock.quantum" = 512;
          "default.clock.min-quantum" = 512;
          "default.clock.max-quantum" = 2048;
          "default.clock.allowed-rates" = [ 44100 48000 ];
        };
      };
    };

    extraConfig.pipewire-pulse = {
      # pulse settings for no suspend
      "92-pulse-no-suspend" = {
        "pulse.properties" = {
          "pulse.min.quantum" = "512/48000";
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
