{ pkgs, username, ... }:

{
  services.lact.enable = true;

  # symlink config from repo
  systemd.tmpfiles.rules = [
    "d /etc/lact 0755 root root -"
    "L+ /etc/lact/config.yaml - - - - /home/${username}/nix-config/system/hardware/lact/config.yaml"
  ];

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
