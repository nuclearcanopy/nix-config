{ lib, ... }:

{
  fileSystems."/" = lib.mkForce
    { device = "/dev/mapper/cryptroot";
      fsType = "ext4";
    };

  fileSystems."/boot" = lib.mkForce
    { device = "/dev/disk/by-partlabel/disk-nidhoggr-boot";
      fsType = "ext4";
    };

  boot.initrd.luks.devices."cryptroot".device =
    lib.mkForce "/dev/disk/by-partlabel/disk-nidhoggr-luks";

  swapDevices = lib.mkForce [ ];
}
