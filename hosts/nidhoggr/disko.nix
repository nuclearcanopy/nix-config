{ device ? "/dev/nvme0n1", luksKeyFile ? null, ... }:

{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = device;
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "fmask=0022" "dmask=0022" ];
              };
            };
            root = {
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
