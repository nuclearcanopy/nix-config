{ pkgs, ... }:

{
  services.lact.enable = true;

  environment.etc."lact/config.yaml".source = ./lact/config.yaml;

  systemd.services.lactd = {
    path = [ pkgs.coreutils ];

    serviceConfig = {
      ReadWritePaths = [ "/etc/lact" ];
      ProtectHome = false;
      ProtectClock = true;
      ProtectHostname = true;
      NoNewPrivileges = true;
      PrivateTmp = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      LockPersonality = true;
      SystemCallArchitectures = "native";
      RestrictAddressFamilies = [ "AF_UNIX" "AF_NETLINK" ];
      AmbientCapabilities = [ "CAP_DAC_OVERRIDE" "CAP_SYS_RAWIO" ];
    };
  };
}
