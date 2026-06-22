{
  # PipeWire setup for laptop (nidhoggr). No JACK, but full RT priority so
  # audio survives CPU throttling, TLP power events, and heavy load. Quantum
  # bumped from 64 (~1.3ms, xrun-prone on battery) to 1024 (~21ms), with a
  # 256 floor so apps can still request lower latency.
  nixos.modules.audio-basic = { pkgs, ... }: {
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

      pulse.enable = true;

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

      extraConfig.pipewire."10-laptop-quantum" = {
        "context.properties" = {
          "default.clock.rate" = 48000;
          "default.clock.quantum" = 1024;
          "default.clock.min-quantum" = 256;
          "default.clock.max-quantum" = 2048;
          "default.clock.allowed-rates" = [ 44100 48000 ];
          "support.dbus" = true;
          "rt.prio" = 88;
          "nice.level" = -11;
        };
      };
    };
  };
}
