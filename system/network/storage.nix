{ ... }:

let
  nasSecrets = import /home/nuclearcanopy/nix-config/nas-secrets.nix;
in
{
  # nas
  fileSystems."/mnt/nas" = {
    device = "//${nasSecrets.nasIp}/${nasSecrets.nasShare}";
    fsType = "cifs";

    options = [
      "credentials=./credentials"
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
