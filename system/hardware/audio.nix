{ pkgs, ... }:

{
  # realtime - disable canary to fix RT priority loss after suspend
  # https://github.com/heftig/rtkit/issues/13
  security.rtkit.enable = true;
  systemd.services.rtkit-daemon.serviceConfig.ExecStart = [
    ""  # clear existing entry
    "${pkgs.rtkit}/libexec/rtkit-daemon --no-canary"
  ];

  # pam limits for realtime audio
  security.pam.loginLimits = [
    { domain = "@audio"; item = "memlock"; type = "-"; value = "unlimited"; }
    { domain = "@audio"; item = "rtprio"; type = "-"; value = "99"; }
    { domain = "@audio"; item = "nice"; type = "-"; value = "-19"; }
  ];

  # usb power
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{bInterfaceClass}=="01", TEST=="power/control", ATTR{power/control}="on"
  '';

  # systemd user service limits for realtime audio
  systemd.user.services.pipewire.serviceConfig = {
    LimitRTPRIO = 95;
    LimitNICE = 40;  # nice level = 20 - value, so 40 = -20
    LimitMEMLOCK = "infinity";
  };
  systemd.user.services.pipewire-pulse.serviceConfig = {
    LimitRTPRIO = 95;
    LimitNICE = 40;
    LimitMEMLOCK = "infinity";
  };
  systemd.user.services.wireplumber.serviceConfig = {
    LimitRTPRIO = 95;
    LimitNICE = 40;
    LimitMEMLOCK = "infinity";
  };

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

    pulse.enable = true;

    extraConfig.pipewire = {
      # low latency + realtime
      "92-low-latency" = {
        "context.properties" = {
          "default.clock.rate" = 48000;
          "default.clock.quantum" = 512;
          "default.clock.min-quantum" = 256;
          "default.clock.max-quantum" = 2048;
          "default.clock.allowed-rates" = [ 44100 48000 ];
          # realtime scheduling via rtkit
          "support.dbus" = true;
          "rt.prio" = 88;
          "nice.level" = -11;
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
