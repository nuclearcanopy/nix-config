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

        # The cachyos ruleset only bumps "prismlauncher" itself (the launcher
        # UI, type "Game", nice -5). The actual game process is the JVM
        # ("java"), which falls through to the default (nice 0) and loses
        # priority to anything else running. Give it more headroom than any
        # stock type does.
        extraTypes = [
          {
            type = "Minecraft";
            nice = -19;
            ioclass = "best-effort";
            ionice = 0;
          }
        ];
        extraRules = [
          { name = "java"; type = "Minecraft"; }
        ];
      };

      # Spread IRQs across cores instead of piling on CPU0. Reduces lag
      # spikes when USB / NVMe / network activity coincides.
      irqbalance.enable = true;
    };
  };
}
