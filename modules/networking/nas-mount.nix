{
  # CIFS mount of the NAS at /mnt/nas with automount + idle-timeout.
  # Credentials decrypted by agenix (nas-credentials secret).
  nixos.modules.nas-mount = { config, pkgs, username, ... }: {
    environment.systemPackages = [ pkgs.cifs-utils ];

    fileSystems."/mnt/nas" = {
      device = "//192.168.0.123/nuclearcanopy";
      fsType = "cifs";

      options = [
        "credentials=${config.age.secrets.nas-credentials.path}"
        "uid=${username}"
        "gid=users"
        "iocharset=utf8"
        "vers=3.1.1"
        "x-systemd.requires=network-online.target"
        "x-systemd.after=network-online.target"
        "x-systemd.automount"
        "noauto"
        "x-systemd.idle-timeout=60"
      ];
    };
  };
}
