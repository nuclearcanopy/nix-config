{ pkgs, ... }:

{
  powerManagement.cpuFreqGovernor = "performance";

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
