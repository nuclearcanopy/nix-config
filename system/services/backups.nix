{ pkgs, username, ... }:

{
  systemd.user.services.librewolf-backup = {
    description = "Backup LibreWolf profiles";

    serviceConfig = {
      Type = "oneshot";
      ExecStartPre = "${pkgs.bash}/bin/bash -c '[ -d /mnt/nas ] || exit 1'";
      ExecStart = "${pkgs.rsync}/bin/rsync -av --delete /home/${username}/.librewolf/ /mnt/nas/librewolf-backup/";
    };
  };
}
