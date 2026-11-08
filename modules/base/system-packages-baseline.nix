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
      python3Packages.scapy

      unzip
      zip
      unrar
      p7zip
      wget
      git
      tree
      rsync
      usbutils
      pciutils

      systemd-manager-tui

      # Hardware diagnostics. None of these were installed when kuraokami
      # threw a fatal MCE on 2026-11-08, which cost a round of `nix shell`
      # just to read SMART data and DIMM layout. Cheap to keep resident on a
      # box with a hardware-fault history. Pairs with the rasdaemon bucket.
      smartmontools # smartctl: disk health, self-tests
      nvme-cli      # nvme smart-log, richer than smartctl on NVMe
      dmidecode     # BIOS/AGESA version, DIMM config, board model
      lm_sensors    # sensors: temps/voltages without reading raw hwmon

      linux-firmware
    ];
  };
}
