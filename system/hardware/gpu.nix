{ pkgs, ... }:

{
  # lact control
  services.lact.enable = true;

  # lact config
  systemd.services.lactd = {
    path = [ pkgs.coreutils ];

    postStart = ''
      mkdir -p /etc/lact
      cp -f ${./lact/config.yaml} /etc/lact/config.yaml
      chmod 644 /etc/lact/config.yaml
    '';

    serviceConfig = {
      # security hardening
      ReadWritePaths = [ "/etc/lact" ];
      ProtectHome = true;
      ProtectKernelModules = true;
      ProtectClock = true;
      ProtectHostname = true;
      ProtectProc = "invisible";
      ProcSubset = "pid";
      NoNewPrivileges = true;
      PrivateTmp = true;
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      SystemCallArchitectures = "native";
      RestrictAddressFamilies = [ "AF_UNIX" "AF_NETLINK" ];

      # capability restrictions 
      #CapabilityBoundingSet = [
      #  "CAP_DAC_OVERRIDE"  # read/write GPU sysfs
      #  "CAP_SYS_RAWIO"     # raw GPU I/O access
      #];
      AmbientCapabilities = [
        "CAP_DAC_OVERRIDE"
        "CAP_SYS_RAWIO"
      ];
    };
  };
}
