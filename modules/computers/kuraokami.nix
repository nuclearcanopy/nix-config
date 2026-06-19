{ config, inputs, ... }:

{
  nixos.configurations.kuraokami = {
    module = { unstable, username, ... }: {
      imports = [
        ../../hosts/kuraokami/hardware-configuration.nix
        inputs.agenix.nixosModules.default

        # ── system buckets ────────────────────────────────────────────
        config.nixos.modules.host-base
        config.nixos.modules.hardening-base
        config.nixos.modules.nix-settings
        config.nixos.modules.overlays
        config.nixos.modules.state-version
        config.nixos.modules.docker
        config.nixos.modules.home-manager-wiring
        config.nixos.modules.system-packages-baseline
        config.nixos.modules.mullvad-autoconnect
        config.nixos.modules.allow-unfree
        config.nixos.modules.gaming
        config.nixos.modules.boot-amd
        config.nixos.modules.secrets
        config.nixos.modules.fonts
        config.nixos.modules.sway-system
        config.nixos.modules.xdg-portal
        config.nixos.modules.audio-jack
        config.nixos.modules.cpu-scheduler
        config.nixos.modules.cpu-governor-performance
        config.nixos.modules.gpu-amd
        config.nixos.modules.graphics-amd
        config.nixos.modules.openrazer
        config.nixos.modules.networking-base
        config.nixos.modules.nas-mount
        config.nixos.modules.services-core
        config.nixos.modules.privacy
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
          config.homeManager.modules.home-base
          config.homeManager.modules.sway-base
          config.homeManager.modules.sway-host
          config.homeManager.modules.sway-startup
          config.homeManager.modules.mako
          config.homeManager.modules.theme
          config.homeManager.modules.gui-packages
          config.homeManager.modules.waybar
          config.homeManager.modules.zsh
          config.homeManager.modules.shell-packages
          config.homeManager.modules.environment
          config.homeManager.modules.alacritty
          config.homeManager.modules.ssh
          config.homeManager.modules.asunder
          config.homeManager.modules.btop
          config.homeManager.modules.easyeffects
          config.homeManager.modules.firefox
          config.homeManager.modules.neovim
          config.homeManager.modules.user-packages
          config.homeManager.modules.steam-home
          config.homeManager.modules.vesktop
          config.homeManager.modules.vkbasalt
          config.homeManager.modules.claudecode
          config.homeManager.modules.git
          config.homeManager.modules.gpg
          config.homeManager.modules.dev-packages
        ];

        waybar.profile = "kuraokami";
      };
    };
  };
}
