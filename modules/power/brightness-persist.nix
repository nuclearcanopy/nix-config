{
  # Persist user-set screen brightness across reboot and resume.
  # Writes the post-change percent to /var/lib/screen-brightness/value
  # whenever set-brightness is invoked (Fn keys, waybar scroll). On boot
  # a oneshot service applies that value, overriding systemd-backlight's
  # last-second save (which often captures a dimmed value at shutdown).
  nixos.modules.brightness-persist = { pkgs, ... }:
    let
      stateDir = "/var/lib/screen-brightness";
      stateFile = "${stateDir}/value";

      setBrightness = pkgs.writeShellApplication {
        name = "set-brightness";
        runtimeInputs = [ pkgs.brightnessctl pkgs.coreutils ];
        text = ''
          # Apply brightness via brightnessctl, then persist the resulting
          # percent so we can restore it on boot. Args are passed through.
          brightnessctl -e4 -n2 set "$@" >/dev/null
          for b in /sys/class/backlight/*; do
            [ -d "$b" ] || continue
            cur=$(cat "$b/brightness")
            max=$(cat "$b/max_brightness")
            pct=$(( cur * 100 / max ))
            printf '%s\n' "$pct" > "${stateFile}" 2>/dev/null || true
            break
          done
        '';
      };

      restoreBrightness = pkgs.writeShellScript "brightness-restore" ''
        f="${stateFile}"
        [ -r "$f" ] || exit 0
        val=$(${pkgs.coreutils}/bin/cat "$f")
        if [ -z "$val" ] || ! [ "$val" -eq "$val" ] 2>/dev/null; then
          exit 0
        fi
        ${pkgs.brightnessctl}/bin/brightnessctl set "''${val}%" >/dev/null || true
      '';
    in
    {
      environment.systemPackages = [ setBrightness ];

      systemd.tmpfiles.rules = [
        "d ${stateDir} 0775 root users - -"
        "f ${stateFile} 0664 root users - -"
      ];

      systemd.services.brightness-restore = {
        description = "Restore screen brightness from persistent state";
        wantedBy = [ "multi-user.target" ];
        after = [ "systemd-backlight@backlight:acpi_video0.service" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = restoreBrightness;
        };
      };
    };
}
