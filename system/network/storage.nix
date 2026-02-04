{ ... }:

{
  # nas mount
  fileSystems."/mnt/nas" = {
    device = "//192.168.0.123/nuclearcanopy";
    fsType = "cifs";

    options = [
      "username=mihaita"
      "password=REDACTED"  # todo: credentials file
      "uid=nuclearcanopy"
      "gid=users"
      "iocharset=utf8"
      "vers=3.1.1"
      "x-systemd.automount"
      "noauto"
      "x-systemd.idle-timeout=60"
    ];
  };
}
