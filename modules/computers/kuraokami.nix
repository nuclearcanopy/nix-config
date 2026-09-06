{ config, inputs, ... }:

{
  nixos.configurations.kuraokami = {
    username = inputs.identity.usernames.kuraokami;
    module = { unstable, username, ... }: {
      imports = [
        ../../hosts/kuraokami/hardware-configuration.nix
        inputs.agenix.nixosModules.default
        config.nixos.modules.desktop-base

        # ── kuraokami-specific (AMD desktop) ──────────────────────────
        config.nixos.modules.boot-amd
        config.nixos.modules.gpu-amd
        config.nixos.modules.graphics-amd
        config.nixos.modules.cpu-governor-performance
        config.nixos.modules.audio-jack
        config.nixos.modules.openrazer
      ];

      # ── host-specific ────────────────────────────────────────────────
      zramSwap = {
        enable = true;
        algorithm = "zstd";
        memoryPercent = 33;
      };

      # ── home-manager users ───────────────────────────────────────────
      home-manager.users.${username} = {
        imports = [
          config.homeManager.modules.desktop-home-base

          # ── kuraokami-specific ──────────────────────────────────────
          config.homeManager.modules.asunder
          config.homeManager.modules.steam-home
          config.homeManager.modules.vkbasalt
          config.homeManager.modules.user-packages
        ];

        waybar.profile = "kuraokami";
      };
    };
  };
}
