{ config, ... }:

{
  # Shared sway-desktop profile: the system + home-manager buckets that
  # kuraokami (AMD desktop) and nidhoggr (T480 laptop) both use. Hosts import
  # these and add only their hardware/role-specific deltas. The homeserver is
  # headless and does not use this profile.
  nixos.modules.desktop-base = {
    imports = [
      # base
      config.nixos.modules.host-base
      config.nixos.modules.hardening-base
      config.nixos.modules.nix-settings
      config.nixos.modules.overlays
      config.nixos.modules.state-version
      config.nixos.modules.docker
      config.nixos.modules.home-manager-wiring
      config.nixos.modules.system-packages-baseline
      config.nixos.modules.allow-unfree
      config.nixos.modules.secrets

      # networking
      config.nixos.modules.mullvad-autoconnect
      config.nixos.modules.networking-base
      config.nixos.modules.nas-mount

      # desktop / gui
      config.nixos.modules.fonts
      config.nixos.modules.sway-system
      config.nixos.modules.xdg-portal
      config.nixos.modules.thunar

      # hardware / misc
      config.nixos.modules.cpu-scheduler
      config.nixos.modules.v4l2loopback
      config.nixos.modules.gaming
      config.nixos.modules.services-core
      config.nixos.modules.privacy
    ];
  };

  homeManager.modules.desktop-home-base = {
    imports = [
      # sway / desktop shell
      config.homeManager.modules.home-base
      config.homeManager.modules.sway-base
      config.homeManager.modules.sway-host
      config.homeManager.modules.sway-startup
      config.homeManager.modules.mako
      config.homeManager.modules.theme
      config.homeManager.modules.gui-packages
      config.homeManager.modules.waybar

      # shell / terminal
      config.homeManager.modules.zsh
      config.homeManager.modules.shell-packages
      config.homeManager.modules.environment
      config.homeManager.modules.alacritty
      config.homeManager.modules.ssh

      # apps
      config.homeManager.modules.btop
      config.homeManager.modules.easyeffects
      config.homeManager.modules.firefox
      config.homeManager.modules.neovim
      config.homeManager.modules.vesktop

      # dev
      config.homeManager.modules.claudecode
      config.homeManager.modules.git
      config.homeManager.modules.gpg
      config.homeManager.modules.dev-packages
    ];
  };
}
