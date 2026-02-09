{ pkgs, ... }:

{
  # lact
  services.lact.enable = true;

  # Declaratively manage LACT config
  environment.etc."lact/config.yaml" = {
    source = ./lact/config.yaml;
    mode = "0644";
  };

  # Service configuration
  systemd.services.lactd = {
    path = [ pkgs.coreutils ];

    serviceConfig = {
      # Allow LACT to write to its config directory
      ReadWritePaths = [ "/etc/lact" ];

      # Basic hardening that doesn't interfere with LACT
      ProtectHome = true;
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
