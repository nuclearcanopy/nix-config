{
  # Core desktop services: polkit, logind, libinput, flatpak, plus profile-sync-daemon
  # for Firefox RAM-backed profiles and an rtl8111 NIC power-quirk fix.
  nixos.modules.services-core = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.ethtool ];

    security = {
      polkit.enable = true;
      protectKernelImage = true;
    };

    # Route crashes through systemd-coredump but keep nothing on disk. The old
    # `enable = false` removed the handler, so core_pattern fell back to the bare
    # kernel default `core` and every crashing user app (easyeffects mostly) wrote
    # a core.<pid> into its CWD = $HOME (68 files, ~1.9G by 2026-08). Storage=none
    # keeps the journal crash metadata for debugging without ever writing a file.
    systemd.coredump.enable = true;
    systemd.coredump.settings.Coredump = {
      Storage = "none";
      ProcessSizeMax = 0;
    };

    # Journald ships with no size cap beyond "10% of the filesystem", which on a
    # 234G root is ~23G. It had grown to 2.1G by 2026-09-15, largely from the
    # WD SN720's correctable PCIe AER chatter (~1000 RxErr retries per boot, on
    # 0000:07:00.0 behind root port 0000:00:1d.2). Those are link-layer retries
    # with no data risk, and AER reporting is deliberately left on because the
    # AX210 resume failure is detected as a *fatal* AER event. So cap the journal
    # rather than silence the source.
    services.journald.extraConfig = ''
      SystemMaxUse=512M
      SystemMaxFileSize=64M
      MaxRetentionSec=1month
    '';

    services.udev.extraRules = ''
      # fix rtl8111 drops
      ACTION=="add", SUBSYSTEM=="net", ATTR{device/vendor}=="0x10ec", ATTR{device/device}=="0x8168", RUN+="${pkgs.bash}/bin/sh -c 'echo off > /sys/class/net/%k/device/power/control'"
    '';

    # Keep browser profiles in tmpfs (RAM); faster reads, fewer SSD writes.
    # Pairs with the firefox-preload prelauncher in the firefox bucket.
    services.psd = {
      enable = true;
      resyncTimer = "30min";
    };

    services = {
      logind.settings.Login.HandlePowerKey = "suspend";

      libinput.enable = true;

      flatpak.enable = true;

      avahi.enable = false;
    };
  };
}
