{ pkgs, ... }:

{
  # rtkit - no canary fixes RT priority loss after suspend
  # https://github.com/heftig/rtkit/issues/13
  security.rtkit.enable = true;
  systemd.services.rtkit-daemon.serviceConfig.ExecStart = [
    ""
    "${pkgs.rtkit}/libexec/rtkit-daemon --no-canary"
  ];

  security.pam.loginLimits = [
    { domain = "@audio"; item = "memlock"; type = "-"; value = "unlimited"; }
    { domain = "@audio"; item = "rtprio"; type = "-"; value = "99"; }
    { domain = "@audio"; item = "nice"; type = "-"; value = "-19"; }
  ];

  # usb audio power
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{bInterfaceClass}=="01", TEST=="power/control", ATTR{power/control}="on"
  '';

  systemd.user.services.pipewire.serviceConfig = {
    LimitRTPRIO = 95;
    LimitNICE = 19;
    LimitMEMLOCK = "infinity";
  };
  systemd.user.services.pipewire-pulse.serviceConfig = {
    LimitRTPRIO = 95;
    LimitNICE = 19;
    LimitMEMLOCK = "infinity";
  };
  systemd.user.services.wireplumber.serviceConfig = {
    LimitRTPRIO = 95;
    LimitNICE = 19;
    LimitMEMLOCK = "infinity";
  };

  services.pipewire = {
    enable = true;

    alsa = {
      enable = true;
      support32Bit = true;
    };

    jack.enable = true;

    wireplumber.extraConfig = {
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
}
