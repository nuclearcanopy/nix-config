{
  # scx_lavd userspace scheduler + ananicy nice/io tuning + performance governor.
  # Desktop-only; laptop uses TLP-driven governors.
  nixos.modules.cpu-scheduler = { pkgs, ... }: {
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
  };
}
