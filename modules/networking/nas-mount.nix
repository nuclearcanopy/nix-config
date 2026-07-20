{
  # CIFS mount of the NAS at /mnt/nas with automount + idle-timeout.
  # Credentials decrypted by agenix (nas-credentials secret). _netdev and
  # nofail keep boot resilient on the laptop where networks come and go.
  nixos.modules.nas-mount = { config, pkgs, username, ... }: {
    environment.systemPackages = [ pkgs.cifs-utils ];

    fileSystems."/mnt/nas" = {
      # Share name is the NAS account ("loki"), not the local OS user; on
      # kuraokami the username is "user" so it must not be interpolated.
      device = "//192.168.0.123/loki";
      fsType = "cifs";

      options = [
        "credentials=${config.age.secrets.nas-credentials.path}"
        "uid=${username}"
        "gid=users"
        "iocharset=utf8"
        "vers=3.1.1"
        "_netdev"
        "x-systemd.requires=network-online.target"
        "x-systemd.after=network-online.target"
        "x-systemd.automount"
        "x-systemd.mount-timeout=10"
        "noauto"
        "nofail"
        "x-systemd.idle-timeout=60"
      ];
    };
  };
}
