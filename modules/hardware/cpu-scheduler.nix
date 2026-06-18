{
  # scx_lavd userspace scheduler + ananicy nice/io tuning.
  # Governor is split into its own bucket (cpu-governor-performance) since
  # the laptop lets TLP drive the governor instead.
  nixos.modules.cpu-scheduler = { pkgs, ... }: {
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
