{ config, inputs, ... }:

{
  nixos.configurations.nidhoggr = {
    username = "loki";
    module = { unstable, username, ... }: {
      imports = [
        ../../hosts/nidhoggr/hardware-configuration.nix
        inputs.agenix.nixosModules.default

        # ── system buckets ────────────────────────────────────────────
        config.nixos.modules.host-base
        config.nixos.modules.hardening-base
        config.nixos.modules.hardening-physical
        config.nixos.modules.nix-settings
        config.nixos.modules.overlays
        config.nixos.modules.state-version
        config.nixos.modules.docker
        config.nixos.modules.home-manager-wiring
        config.nixos.modules.system-packages-baseline
        config.nixos.modules.system-packages-laptop
        config.nixos.modules.mullvad-autoconnect
        config.nixos.modules.allow-unfree
        config.nixos.modules.gaming
        config.nixos.modules.boot-t480
        config.nixos.modules.boot-optimizations
        config.nixos.modules.secrets
        config.nixos.modules.fonts
        config.nixos.modules.sway-system
        config.nixos.modules.xdg-portal
        config.nixos.modules.audio-basic
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

      # ── host-specific ────────────────────────────────────────────────
      zramSwap = {
        enable = true;
        algorithm = "zstd";
        memoryPercent = 50;
      };

      virtualisation.docker.enableOnBoot = false; # socket-activated; starts on demand

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
          config.homeManager.modules.neovim
          config.homeManager.modules.user-packages-laptop
          config.homeManager.modules.vesktop
          config.homeManager.modules.claudecode
          config.homeManager.modules.git
          config.homeManager.modules.gpg
          config.homeManager.modules.dev-packages
        ];

        waybar.profile = "laptop";
      };
    };
  };
}
