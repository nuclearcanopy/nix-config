{
  # Shared PipeWire/rtkit/RT-priority scaffolding for both audio buckets
  # (audio-basic on nidhoggr, audio-jack on kuraokami). Each host bucket
  # imports this and adds only its quantum tuning and JACK-specific bits.
  nixos.modules.audio-rt-base = { pkgs, ... }: {
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

    # LimitNICE uses systemd's scale form: value = 20 - nice. So 40 allows
    # nice level -20 (max negative). Previously 19 = ceiling +1, which blocked
    # mod.rt's request for nice=-11 and left the audio thread at nice 0. Any
    # CPU spike then caused ~10ms xruns during video calls (staggered voice,
    # micro-glitches). Symptom in journal: `mod.rt: could not set nice-level
    # to -11: Permission denied` on every pipewire/wireplumber startup.
    systemd.user.services.pipewire.serviceConfig = {
      LimitRTPRIO = 95;
      LimitNICE = 40;
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
    };
  };
}
