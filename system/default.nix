{ ... }:

{
  imports = [
    # Core system configuration
    ./core/boot.nix
    ./core/nix.nix
    ./core/packages.nix
    ./core/impermanence.nix

    # Desktop environment
    ./desktop/sway.nix
    ./desktop/fonts.nix
    ./desktop/xdg.nix

    # Hardware management
    ./hardware/audio.nix
    ./hardware/gpu.nix
    ./hardware/cpu.nix

    # Network configuration
    ./network/base.nix
    ./network/storage.nix

    # System services
    ./services/system.nix
    ./services/flatpak.nix
    ./services/backups.nix
    ./services/privacy.nix
  ];
}
