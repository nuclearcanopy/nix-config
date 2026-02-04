{ pkgs, ... }:

{
  # schedulers
  services = {
    # sched_ext
    scx = {
      enable = true;
      scheduler = "scx_lavd";
    };

    # priority
    ananicy = {
      enable = true;
      rulesProvider = pkgs.ananicy-rules-cachyos;
    };
  };
}
