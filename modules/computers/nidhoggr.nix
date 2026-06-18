{ config, inputs, ... }:

{
  nixos.configurations.nidhoggr = {
    username = "nuclearcanopy";
    module = { unstable, username, ... }: {
      imports = [
        ../../hosts/nidhoggr/hardware-configuration.nix
        inputs.agenix.nixosModules.default
        inputs.home-manager.nixosModules.home-manager

        # ── system buckets ────────────────────────────────────────────
        config.nixos.modules.host-base
        config.nixos.modules.hardening
        config.nixos.modules.hardening-laptop
        config.nixos.modules.nix-settings
        config.nixos.modules.system-packages-baseline
        config.nixos.modules.system-packages-laptop
        config.nixos.modules.mullvad-autoconnect
        config.nixos.modules.allow-unfree
        config.nixos.modules.gaming
        config.nixos.modules.boot-laptop
        config.nixos.modules.boot-laptop-optimizations
        config.nixos.modules.secrets
        config.nixos.modules.fonts
        config.nixos.modules.sway-system
        config.nixos.modules.xdg-portal
        config.nixos.modules.audio-laptop
        config.nixos.modules.cpu-scheduler
        config.nixos.modules.graphics-intel
        config.nixos.modules.trackpoint
        config.nixos.modules.trackpad-synaptics
        config.nixos.modules.bluetooth-disable
        config.nixos.modules.networking-base
        config.nixos.modules.network-laptop
        config.nixos.modules.mullvad-graphical-target
        config.nixos.modules.nas-mount
        config.nixos.modules.services-core
        config.nixos.modules.privacy
        config.nixos.modules.earlyoom
        config.nixos.modules.displaymanager-ly
        config.nixos.modules.tpm2-off
        config.nixos.modules.luks-initrd
        config.nixos.modules.virtualisation
        config.nixos.modules.openrazer

        # ── power buckets ─────────────────────────────────────────────
        config.nixos.modules.tlp
        config.nixos.modules.cpu-modes
        config.nixos.modules.thinkfan
        config.nixos.modules.undervolt
        config.nixos.modules.fwupd
        config.nixos.modules.power-suspend
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
        memoryPercent = 50;
      };

      virtualisation.docker = {
        enable = true;
        enableOnBoot = false; # socket-activated; starts on demand
      };

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
            config.homeManager.modules.swayidle
            config.homeManager.modules.zsh
            config.homeManager.modules.shell-packages
            config.homeManager.modules.environment
            config.homeManager.modules.alacritty
            config.homeManager.modules.ssh
            config.homeManager.modules.btop
            config.homeManager.modules.easyeffects
            config.homeManager.modules.easyeffects-service
            config.homeManager.modules.firefox
            config.homeManager.modules.firefox-laptop
            config.homeManager.modules.neovim
            config.homeManager.modules.user-packages-laptop
            config.homeManager.modules.vesktop
            config.homeManager.modules.claudecode
            config.homeManager.modules.git
            config.homeManager.modules.gpg
            config.homeManager.modules.dev-packages
          ];

          waybar.profile = "laptop";

          # ── nidhoggr-specific sway: laptop outputs + ThinkPad keyboard remap
          wayland.windowManager.sway = {
            config = {
              keybindings = {
                "Mod4+Mod1+4" = "exec ${../gui/waybar/scripts/thermal_toggle.sh}";
              };

              output = {
                "*" = {
                  bg = "#000000 solid_color";
                };
                # external HDMI sits on top, laptop panel directly below
                "HDMI-A-2" = {
                  position = "0 0";
                };
                "eDP-1" = {
                  position = "0 1440";
                };
              };

              input = {
                "*" = {
                  xkb_layout = "us";
                  accel_profile = "flat";
                  pointer_accel = "-0.5";
                };

                # xkb_options only on the internal keyboard; HHKB unaffected
                "1:2:AT_Raw_Set_2_keyboard" = {
                  xkb_options = "ctrl:nocaps,ctrl:swap_lalt_lctl";
                };

                "2:10:TPPS/2_IBM_TrackPoint" = {
                  accel_profile = "flat";
                  pointer_accel = "0.3";
                  scroll_factor = "0.25";
                };

                "type:touchpad" = {
                  accel_profile = "adaptive";
                  pointer_accel = "-0.1";
                  natural_scroll = "enabled";
                  tap = "disabled";
                  dwt = "disabled";
                  middle_emulation = "enabled";
                };
              };

              startup = [
                { command = "autotiling-rs"; }
                { command = "swaymsg workspace 1"; }
              ];
            };
          };
        };
      };
    };
  };
}
