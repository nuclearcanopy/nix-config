{ pkgs, ... }:

{
  # cpu schedulers
  services = {
    # sched_ext
    scx = {
      enable = true;
      scheduler = "scx_lavd";
    };

    # process priority
    ananicy = {
      enable = true;
      rulesProvider = pkgs.ananicy-rules-cachyos;
    };
  };
}
