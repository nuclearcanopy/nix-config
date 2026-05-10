{ pkgs, ... }:

# CPU governor is intentionally NOT set here — TLP (power.nix) manages it
# per AC/BAT state for best efficiency. scx_lavd adapts to power state automatically
# and ananicy keeps interactive tasks snappy without pinning frequency up.
{
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
