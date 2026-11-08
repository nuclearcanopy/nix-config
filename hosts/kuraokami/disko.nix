{ device ? "/dev/nvme0n1", ... }:

# ⚠ DUAL BOOT: this disk also carries a Windows install (partition 3, for
# League of Legends / Vanguard, which cannot run under Wine). disko DESTROYS
# THE WHOLE DISK when it runs. Re-running `scripts/install.sh` against this
# host wipes Windows along with NixOS. There is no partial / preserve mode.
#
# The layout below is the *intended* layout for a fresh install. The currently
# running system predates it and differs in two ways:
#   - its ESP is 512M (this file now asks for 1G; see note on ESP below)
#   - its root was created with size = "100%" and was shrunk offline afterwards
# Do not "fix" the running disk to match this file; only a reinstall applies it.

{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = device;
        content = {
          type = "gpt";
          partitions = {
            # 1G, not 512M: the ESP is shared with the Windows bootloader.
            # Each distinct kernel build costs ~41M here (kernel 13.5M +
            # initrd 27.8M; generations sharing a kernel dedupe), and Windows
            # Boot Manager adds ~30-60M. 512M works but leaves room for only
            # ~10 kernel pairs; 1G removes the need to think about it.
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "fmask=0022" "dmask=0022" ];
              };
            };
            # Fixed size, NOT "100%": the tail of the disk is reserved for
            # Windows. If this ever goes back to "100%" the Windows partition
            # silently stops fitting and a reinstall eats it.
            root = {
              size = "700G";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
            # Created bare (no `content`, so disko partitions but does not
            # format it). The Windows installer formats this NTFS itself and
            # carves its own MSR + recovery partitions out of the slack.
            windows = {
              size = "100%";
              type = "0700";
            };
          };
        };
      };
    };
  };
}
