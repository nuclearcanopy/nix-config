{ pkgs, ... }:

# CPU governor is intentionally NOT set here — TLP (power.nix) manages it
# per AC/BAT state for best efficiency. scx_lavd adapts to power state automatically
# and ananicy keeps interactive tasks snappy without pinning frequency up.
let
  # Ryzen 5500U: default TDP is 15W. On AC we raise power limits so boost
  # sustains longer. On battery we restore conservative defaults.
  ryzenadj-ac = pkgs.writeShellScript "ryzenadj-ac" ''
    if [ "$(cat /sys/class/power_supply/AC0/online 2>/dev/null || cat /sys/class/power_supply/ACAD/online 2>/dev/null || echo 0)" = "1" ]; then
      ${pkgs.ryzenadj}/bin/ryzenadj \
        --stapm-limit=28000 \
        --fast-limit=35000 \
        --slow-limit=30000 \
        --tctl-temp=90
    else
      ${pkgs.ryzenadj}/bin/ryzenadj \
        --stapm-limit=15000 \
        --fast-limit=18000 \
        --slow-limit=15000 \
        --tctl-temp=85
    fi
  '';
in
{
  environment.systemPackages = [ pkgs.ryzenadj ];

  # Apply ryzenadj on boot and when AC state changes
  systemd.services.ryzenadj = {
    description = "Apply Ryzen power limits based on AC state";
    after = [ "multi-user.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = ryzenadj-ac;
    };
  };

  # Re-apply when charger is plugged/unplugged
  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", ATTR{type}=="Mains", RUN+="${ryzenadj-ac}"
  '';

  services = {
    scx = {
      enable = true;
      scheduler = "scx_lavd";
    };

    ananicy = {
      enable = true;
      rulesProvider = pkgs.ananicy-rules-cachyos;
    };
  };
}
