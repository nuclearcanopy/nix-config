{ pkgs, username, ... }:

{
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = false;
      swtpm.enable = true;
      ovmf = {
        enable = true;
        packages = [ pkgs.OVMFFull ];
      };
    };
  };

  virtualisation.spiceUSBRedirection.enable = true;

  programs.virt-manager.enable = true;

  users.users.${username}.extraGroups = [ "libvirtd" "kvm" ];

  environment.systemPackages = [ pkgs.virt-viewer ];
}
