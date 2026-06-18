{
  nixos.modules.system-packages-baseline = { pkgs, ... }: {
    # Sets dumpcap capabilities and creates the wireshark group so non-root
    # users in that group can capture. Membership is in the host-base bucket.
    programs.wireshark = {
      enable = true;
      package = pkgs.wireshark; # GUI; default is wireshark-cli
    };

    environment.systemPackages = with pkgs; [
      wireguard-tools
      dnsutils

      unzip
      zip
      unrar
      p7zip
      wget
      git
      rsync
      usbutils
      pciutils

      systemd-manager-tui

      linux-firmware
    ];
  };
}
