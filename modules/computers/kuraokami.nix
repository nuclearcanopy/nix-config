{ config, inputs, ... }:

{
  nixos.configurations.kuraokami = {
    username = "nuclearcanopy";
    module = { unstable, username, ... }: {
      imports = [
        ../../hosts/kuraokami/hardware-configuration.nix
        inputs.agenix.nixosModules.default
        inputs.home-manager.nixosModules.home-manager

        # ── system buckets ────────────────────────────────────────────
        config.nixos.modules.host-base
        config.nixos.modules.hardening
        config.nixos.modules.nix-settings
        config.nixos.modules.system-packages-baseline
        config.nixos.modules.mullvad-autoconnect
        config.nixos.modules.allow-unfree
        config.nixos.modules.gaming
        config.nixos.modules.boot-amd
        config.nixos.modules.secrets
        config.nixos.modules.fonts
        config.nixos.modules.sway-system
        config.nixos.modules.xdg-portal
        config.nixos.modules.audio
        config.nixos.modules.cpu-scheduler
        config.nixos.modules.cpu-governor-performance
        config.nixos.modules.gpu-amd
        config.nixos.modules.graphics
        config.nixos.modules.openrazer
        config.nixos.modules.networking-base
        config.nixos.modules.nas-mount
        config.nixos.modules.services-core
        config.nixos.modules.privacy
      ];

      nixpkgs.overlays = [
        inputs.cachyos-kernel.overlays.pinned
        inputs.nur.overlays.default
      ];

      # ── host-specific ────────────────────────────────────────────────
      system.stateVersion = "25.11";

      zramSwap = {
        enable = true;
        algorithm = "zstd";
        memoryPercent = 33;
      };

      virtualisation.docker.enable = true;

      # ── home-manager wiring ──────────────────────────────────────────
      home-manager = {
        extraSpecialArgs = { inherit unstable username; };
        sharedModules = [ inputs.nixvim.homeModules.nixvim ];
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "backup";

        users.${username} = {
          imports = [
            config.homeManager.modules.home-base
            config.homeManager.modules.sway-base
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

          # ── kuraokami-specific sway outputs/inputs/startup ──────────
          wayland.windowManager.sway = {
            config = {
              output = {
                "DP-1" = {
                  mode = "2560x1440@120Hz";
                  position = "0,0";
                  scale = "1";
                  bg = "#000000 solid_color";
                };
                "DP-2" = {
                  mode = "2560x1440@120Hz";
                  position = "2560,0";
                  scale = "1";
                  bg = "#000000 solid_color";
                };
                "HDMI-A-2" = {
                  mode = "1920x1080@60Hz";
                  position = "0,1440";
                  scale = "1";
                  bg = "#000000 solid_color";
                };
              };

              workspaceOutputAssign = [
                { workspace = "1"; output = "DP-1"; }
                { workspace = "2"; output = "DP-2"; }
              ];

              input = {
                "*" = {
                  xkb_layout = "us";
                  accel_profile = "flat";
                  pointer_accel = "-0.84";
                };

                "type:touchpad" = {
                  natural_scroll = "disabled";
                };

                "type:tablet_tool" = {
                  map_to_output = "HDMI-A-2";
                };
              };

              startup = [
                { command = "easyeffects -w"; }
                { command = "autotiling-rs"; }
              ];
            };

            extraConfig = ''
              output DP-1 adaptive_sync on
            '';
          };
        };
      };
    };
  };
}
