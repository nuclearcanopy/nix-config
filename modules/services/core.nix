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
    services.psd = {
      enable = true;
      resyncTimer = "30min";
    };

    # psd snapshots the on-disk profile to <profile>-backup-crashrecovery-<ts>
    # and <profile>-old-profile-<ts> on an unclean exit, and never prunes them.
    # 94 had accumulated (8.7G, oldest 2026-08-02) by 2026-10-30, growing ~1.8G
    # a week across the three firefox profiles. Keep a week's worth; the live
    # profile symlink and the current <profile>-backup are never matched.
    systemd.user.services.psd-prune = {
      description = "Prune stale profile-sync-daemon profile snapshots";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.writeShellApplication {
          name = "psd-prune";
          runtimeInputs = [ pkgs.findutils ];
          text = ''
            dir="$HOME/.mozilla/firefox"
            [ -d "$dir" ] || exit 0
            find "$dir" -mindepth 1 -maxdepth 1 -type d \
              \( -name '*-backup-crashrecovery-[0-9]*_[0-9]*' \
              -o -name '*-old-profile-[0-9]*_[0-9]*' \) \
              -mtime +7 -exec rm -rf -- {} + || true
          '';
        }}/bin/psd-prune";
      };
    };

    systemd.user.timers.psd-prune = {
      description = "Daily prune of stale profile-sync-daemon snapshots";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };

    services = {
      logind.settings.Login.HandlePowerKey = "suspend";

      libinput.enable = true;

      flatpak.enable = true;

      avahi.enable = false;
    };
  };
}
