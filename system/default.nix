{ ... }:

{
  imports = [
    # Secrets management
    ./secrets.nix

    # Core system configuration
    ./core/boot.nix
    ./core/nix.nix
    ./core/packages.nix

    # Desktop environment
    ./desktop/sway.nix
    ./desktop/fonts.nix
    ./desktop/xdg.nix

    # Hardware management
    ./hardware/audio.nix
    ./hardware/gpu.nix
    ./hardware/cpu.nix
    ./hardware/openrazer.nix

    # Network configuration
    ./network/base.nix
    ./network/storage.nix
    # ./network/tuning.nix

    # System services
    ./services/system.nix
    ./services/flatpak.nix
    ./services/privacy.nix
  ];
}
