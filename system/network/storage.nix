{ secrets, username, pkgs, ... }:

{
  # Create credentials file with restricted permissions (not in nix store)
  system.activationScripts.nas-credentials = ''
    cat > /etc/nas-credentials <<EOF
username=${secrets.nas.username}
password=${secrets.nas.password}
EOF
    chmod 600 /etc/nas-credentials
  '';

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
