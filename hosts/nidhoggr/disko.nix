{ device ? "/dev/nvme0n1", luksKeyFile ? null, ... }:

{
  disko.devices = {
    disk = {
      nidhoggr = {
        type = "disk";
        device = device;
        content = {
          type = "gpt";
          partitions = {
            grub = {
              size = "1M";
              type = "EF02";  # BIOS boot partition — GRUB embeds core.img here (no filesystem)
            };
            boot = {
              size = "512M";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/boot";
              };
            };
            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "cryptroot";
                # passwordFile: used for both luksFormat and luksOpen during install.
                # null = interactive TTY prompt (for manual disko runs).
                # Set via --argstr luksKeyFile /tmp/luks-key by install.sh.
                passwordFile = luksKeyFile;
                settings = {
                  allowDiscards = true;
                };
                content = {
                  type = "filesystem";
                  format = "ext4";
                  mountpoint = "/";
                };
              };
            };
          };
        };
      };
    };
  };
}
