{ secrets, username, config, ... }:

{
  # Create CIFS credentials file in /etc
  environment.etc."nas-credentials".text = ''
    username=${secrets.nas.username}
    password=${secrets.nas.password}
  '';

  # nas
  fileSystems."/mnt/nas" = {
    device = "//${secrets.nas.ip}/${secrets.nas.share}";
    fsType = "cifs";

    options = [
      "credentials=/etc/nas-credentials"
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
