{ pkgs, username, ... }:

{
  # lact
  services.lact.enable = true;

  # Declaratively manage LACT config via out-of-store symlink
  systemd.tmpfiles.rules = [
    "d /etc/lact 0755 root root -"
    "L+ /etc/lact/config.yaml - - - - /home/${username}/nix-config/system/hardware/lact/config.yaml"
  ];

  # Service configuration
  systemd.services.lactd = {
    path = [ pkgs.coreutils ];

    serviceConfig = {
      # Allow LACT to write to its config directory
      ReadWritePaths = [ "/etc/lact" ];

      # Basic hardening that doesn't interfere with LACT
      # ProtectHome disabled - config symlinked from home dir
      ProtectHome = false;
      ProtectClock = true;
      ProtectHostname = true;
      NoNewPrivileges = true;
      PrivateTmp = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      LockPersonality = true;
      SystemCallArchitectures = "native";

      # LACT needs access to GPU hardware
      RestrictAddressFamilies = [ "AF_UNIX" "AF_NETLINK" ];

      # Capabilities for GPU access
      AmbientCapabilities = [
        "CAP_DAC_OVERRIDE"  # GPU sysfs access
        "CAP_SYS_RAWIO"     # GPU I/O operations
      ];
    };
  };
}
