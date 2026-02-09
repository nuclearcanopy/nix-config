{ config, lib, username, ... }:

{
  environment.persistence."/persist" = {
    hideMounts = true;

    directories = [
      "/var/lib/nixos"
      "/var/lib/systemd"
      "/var/log"
      "/etc/ssh"
      "/var/lib/NetworkManager"
    ];

    files = [
      "/etc/machine-id"
    ];
  };

  boot.tmp.useTmpfs = true;
}
