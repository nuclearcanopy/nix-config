{ pkgs, ... }:

let
  brightnessctl = "${pkgs.brightnessctl}/bin/brightnessctl";

  # Script that sets brightness based on current time.
  # Dim window: 22:15 – 08:00 (1% brightness).
  # Bright window: 08:00 – 22:15 (100% brightness).
  checkAndSetScript = pkgs.writeShellScript "screen-brightness-check" ''
    HOUR=$(date +%H)
    MIN=$(date +%M)
    TIME=$(( 10#$HOUR * 60 + 10#$MIN ))
    DIM_START=$(( 22 * 60 + 15 ))   # 1335
    BRIGHT_START=$(( 8 * 60 ))       # 480

    if [ "$TIME" -ge "$DIM_START" ] || [ "$TIME" -lt "$BRIGHT_START" ]; then
      ${brightnessctl} set 1% 2>/dev/null || true
    else
      ${brightnessctl} set 100% 2>/dev/null || true
    fi
  '';
in
{
  environment.systemPackages = [ pkgs.brightnessctl ];

  # ── Boot-time init ───────────────────────────────────────────────────────────
  # Runs after login session is ready, checks time and sets the right level.
  # Since the system reboots at 05:00, this will always apply dim on startup
  # (05:00 < 08:00 = dim window) and the 08:00 timer takes over from there.
  systemd.services.screen-brightness-init = {
    description = "Set screen brightness based on time of day";
    wantedBy = [ "multi-user.target" ];
    after = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = false;
      ExecStart = checkAndSetScript;
    };
  };

  # ── Dim at 22:15 ─────────────────────────────────────────────────────────────
  systemd.services.screen-dim = {
    description = "Dim screen to 1% for night hours";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${brightnessctl} set 1%";
    };
  };

  systemd.timers.screen-dim = {
    description = "Timer: dim screen at 22:15";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 22:15:00";
      Persistent = false; # Don't catch up if missed (handled by init service)
    };
  };

  # ── Brighten at 08:00 ────────────────────────────────────────────────────────
  systemd.services.screen-brighten = {
    description = "Restore screen to full brightness for daytime";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${brightnessctl} set 100%";
    };
  };

  systemd.timers.screen-brighten = {
    description = "Timer: brighten screen at 08:00";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 08:00:00";
      Persistent = false;
    };
  };
}
