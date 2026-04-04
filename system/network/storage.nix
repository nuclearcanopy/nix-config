{ config, username, pkgs, ... }:

{
  # NAS credentials are managed by agenix at /run/agenix/nas-credentials

  fileSystems."/mnt/nas" = {
    device = "//192.168.0.123/nuclearcanopy";
    fsType = "cifs";

    options = [
      "credentials=${config.age.secrets.nas-credentials.path}"
      "uid=${username}"
      "gid=users"
      "iocharset=utf8"
      "vers=3.1.1"
      "x-systemd.automount"
      "noauto"
      "x-systemd.idle-timeout=60"
    ];
  };
}
